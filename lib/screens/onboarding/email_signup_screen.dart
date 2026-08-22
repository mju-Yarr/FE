import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/auth_service.dart";
import "../../network/api_client.dart";
import "../../providers/auth_providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_error_banner.dart";
import "../../widgets/ensom/ensom_pill_button.dart";
import "../../widgets/ensom/ensom_text_field.dart";
import "../../widgets/ensom/ensom_top_bar.dart";
import "email_login_screen.dart";

/// S-16 회원가입 — 이름·닉네임·약관·이메일 인증이 모두 이 폼 안에 있다.
/// 별도 이메일 인증 화면(구 S-17)은 없어졌다(명세 §14).
///
/// §4.1 "이메일 가입은 약관이 폼 안에 있어 S-02를 건너뛴다" — 그래서 여기서
/// 필수 약관 3종(terms·privacy·location)을 모두 받는다. 하나라도 빠지면 BE가
/// REQUIRED_CONSENT_MISSING으로 가입을 거절하고, 다 받으면 로그인 응답의
/// consentRequired가 비어 S-02가 뜨지 않는다.
///
/// §8 폼 게이트 — 이름·닉네임·이메일·비밀번호·비밀번호 확인 전부 입력 AND
/// 비밀번호 8자 이상 + 영문·숫자 포함 AND 확인 일치 AND 필수 약관 체크 AND
/// 이메일 인증 완료. 못 채운 동안 버튼을 숨기지 않고 비활성으로 둔다.
class EmailSignupScreen extends ConsumerStatefulWidget {
  const EmailSignupScreen({super.key});

  @override
  ConsumerState<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends ConsumerState<EmailSignupScreen> {
  static const _requiredConsents = ["terms", "privacy", "location"];

  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _codeController = TextEditingController();

  final _consents = <String, bool>{
    "terms": false,
    "privacy": false,
    "location": false,
    "marketing": false,
  };

  /// confirm이 돌려준 가입용 티켓. 이게 있어야 §8의 "이메일 인증 완료"다.
  VerificationTicket? _ticket;

  /// send 성공 후 코드 입력란을 연다.
  bool _codeSent = false;
  bool _sendingCode = false;
  bool _confirmingCode = false;
  bool _submitting = false;
  String? _error;
  String? _codeError;

  /// §13 "타이머 정리 — 재호출할 때 이전 타이머를 반드시 정리한다".
  Timer? _resendTimer;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _nameController,
      _nicknameController,
      _emailController,
      _passwordController,
      _passwordConfirmController,
      _codeController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
    // 이메일을 고치면 앞서 받은 인증은 무효다. 다른 주소로 받은 티켓으로
    // 가입되는 것을 막는다.
    _emailController.addListener(_invalidateVerification);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _nameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim();
  String get _nickname => _nicknameController.text.trim();
  String get _email => _emailController.text.trim();
  String get _password => _passwordController.text;
  String get _passwordConfirm => _passwordConfirmController.text;

  String? _verifiedEmail;

  void _invalidateVerification() {
    if (_verifiedEmail == null || _verifiedEmail == _email) return;
    setState(() {
      _ticket = null;
      _verifiedEmail = null;
      _codeSent = false;
      _codeController.clear();
      _codeError = null;
    });
  }

  bool get _emailLooksValid =>
      RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(_email);

  // §8 비밀번호 규칙 — 8자 이상, 영문·숫자 포함. BE의 검증 정규식과 같다.
  bool get _pwHasLength => _password.length >= 8;
  bool get _pwHasLetter => RegExp(r"[A-Za-z]").hasMatch(_password);
  bool get _pwHasDigit => RegExp(r"\d").hasMatch(_password);
  bool get _pwValid => _pwHasLength && _pwHasLetter && _pwHasDigit;
  bool get _pwConfirmed =>
      _passwordConfirm.isNotEmpty && _password == _passwordConfirm;

  bool get _emailVerified => _ticket != null && _verifiedEmail == _email;
  bool get _requiredConsentsChecked =>
      _requiredConsents.every((key) => _consents[key] == true);

  bool get _canSubmit =>
      _name.isNotEmpty &&
      _nickname.isNotEmpty &&
      _emailLooksValid &&
      _pwValid &&
      _pwConfirmed &&
      _requiredConsentsChecked &&
      _emailVerified &&
      !_submitting;

  bool get _canSendCode =>
      _emailLooksValid && !_sendingCode && _resendCooldown == 0;

  Future<void> _sendCode() async {
    if (!_canSendCode) return;
    setState(() {
      _sendingCode = true;
      _codeError = null;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).sendVerificationCode(_email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _sendingCode = false;
      });
      _startResendCooldown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _codeError = switch (e.code) {
          "EMAIL_EXISTS" => "이미 가입된 이메일이에요. 로그인해 주세요.",
          "VERIFICATION_RATE_LIMITED" => "인증 요청이 많아요. 잠시 후 다시 시도해 주세요.",
          "EMAIL_DELIVERY_UNAVAILABLE" =>
            "지금은 인증 메일을 보낼 수 없어요. 잠시 후 다시 시도해 주세요.",
          "NETWORK_ERROR" => "네트워크에 연결할 수 없어요.",
          _ => e.message,
        };
      });
    }
  }

  /// BE 재발송 쿨다운(기본 60초)과 맞춘다.
  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) timer.cancel();
    });
  }

  Future<void> _confirmCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6 || _confirmingCode) return;
    setState(() {
      _confirmingCode = true;
      _codeError = null;
    });
    try {
      final ticket = await ref
          .read(authServiceProvider)
          .confirmVerificationCode(email: _email, code: code);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _verifiedEmail = _email;
        _confirmingCode = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _confirmingCode = false;
        _codeError = switch (e.code) {
          "INVALID_VERIFICATION_CODE" => "인증 코드가 맞지 않거나 만료됐어요.",
          "VERIFICATION_RATE_LIMITED" => "시도가 많아요. 잠시 후 다시 시도해 주세요.",
          "NETWORK_ERROR" => "네트워크에 연결할 수 없어요.",
          _ => e.message,
        };
      });
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .signupWithEmail(
            email: _email,
            password: _password,
            verificationTicket: _ticket!.ticket,
            consents: Map<String, bool>.from(_consents),
            name: _name,
            nickname: _nickname,
          );
      if (!mounted) return;
      context.go("/onboarding/signup-complete");
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = switch (e.code) {
          "EMAIL_EXISTS" => "이미 가입된 이메일이에요. 로그인하거나 다른 이메일을 사용해 주세요.",
          "NICKNAME_EXISTS" => "이미 사용 중인 닉네임이에요. 다른 닉네임을 사용해 주세요.",
          "INVALID_VERIFICATION_TICKET" => "이메일 인증이 만료됐어요. 코드를 다시 받아 주세요.",
          "REQUIRED_CONSENT_MISSING" => "필수 약관에 모두 동의해 주세요.",
          "INVALID_PASSWORD" => "비밀번호는 8자 이상이며 영문과 숫자를 포함해야 해요.",
          "NETWORK_ERROR" => "네트워크에 연결할 수 없어요. 잠시 후 다시 시도해 주세요.",
          _ => e.message,
        };
        // 티켓이 만료됐으면 인증부터 다시 받아야 한다.
        if (e.code == "INVALID_VERIFICATION_TICKET") {
          _ticket = null;
          _verifiedEmail = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = "회원가입에 실패했어요. 다시 시도해 주세요.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: const EnsomTopBar(title: "회원가입"),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                children: [
                  if (_error != null) ...[
                    EnsomErrorBanner(title: _error!),
                    const SizedBox(height: 14),
                  ],
                  EnsomTextField(
                    label: "이름",
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  EnsomTextField(
                    label: "닉네임",
                    controller: _nicknameController,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  _buildEmailVerification(),
                  const SizedBox(height: 14),
                  EnsomTextField(
                    label: "비밀번호",
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: EnsomColors.surface2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _PasswordCheck(label: "8자 이상", ok: _pwHasLength),
                        _PasswordCheck(label: "영문 포함", ok: _pwHasLetter),
                        _PasswordCheck(label: "숫자 포함", ok: _pwHasDigit),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  EnsomTextField(
                    label: "비밀번호 확인",
                    controller: _passwordConfirmController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    helperText: _passwordConfirm.isEmpty || _pwConfirmed
                        ? null
                        : "비밀번호가 일치하지 않아요.",
                    helperTone: EnsomFieldTone.bad,
                  ),
                  const SizedBox(height: 18),
                  _buildConsents(),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: const BoxDecoration(
                color: EnsomColors.surface1,
                border: Border(top: BorderSide(color: EnsomColors.hairline)),
              ),
              child: Column(
                children: [
                  EnsomPillButton(
                    label: _submitting ? "가입 중..." : "회원가입",
                    onPressed: _canSubmit ? _submit : null,
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const EmailLoginScreen(),
                              ),
                            );
                          },
                    child: const Text(
                      "이미 계정이 있으신가요? 로그인",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: EnsomColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailVerification() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: EnsomTextField(
                label: "이메일",
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                // 인증 후에도 잠그지 않는다. 오타를 고칠 수 있어야 하고,
                // 주소가 바뀌면 _invalidateVerification이 인증을 무효화한다.
                helperText: _email.isEmpty || _emailLooksValid
                    ? null
                    : "이메일 형식을 확인해주세요.",
                helperTone: EnsomFieldTone.bad,
              ),
            ),
            const SizedBox(width: 10),
            // EnsomPillButton의 minimumSize가 Size.fromHeight(무한 너비)라
            // Row 안에서는 폭을 명시해야 한다.
            SizedBox(
              width: 92,
              height: 46,
              child: EnsomPillButton(
                label: _resendLabel,
                variant: EnsomPillVariant.secondary,
                onPressed: _emailVerified || !_canSendCode ? null : _sendCode,
              ),
            ),
          ],
        ),
        if (_emailVerified) ...[
          const SizedBox(height: 8),
          const _VerifiedBadge(),
        ] else if (_codeSent) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: EnsomTextField(
                  label: "인증 코드 6자리",
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _confirmCode(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 92,
                height: 46,
                child: EnsomPillButton(
                  label: _confirmingCode ? "확인 중" : "확인",
                  onPressed: _codeController.text.trim().length == 6
                      ? _confirmCode
                      : null,
                ),
              ),
            ],
          ),
        ],
        if (_codeError != null) ...[
          const SizedBox(height: 8),
          EnsomErrorBanner(title: _codeError!),
        ],
      ],
    );
  }

  String get _resendLabel {
    if (_sendingCode) return "전송 중";
    if (_resendCooldown > 0) return "$_resendCooldown초";
    return _codeSent ? "재전송" : "인증 요청";
  }

  Widget _buildConsents() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: EnsomColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EnsomColors.hairline),
      ),
      child: Column(
        children: [
          _ConsentRow(
            label: "이용약관 동의",
            required: true,
            value: _consents["terms"]!,
            onChanged: (value) => setState(() => _consents["terms"] = value),
            onView: () => context.push("/terms/tos"),
          ),
          _ConsentRow(
            label: "개인정보 처리방침 동의",
            required: true,
            value: _consents["privacy"]!,
            onChanged: (value) => setState(() => _consents["privacy"] = value),
            onView: () => context.push("/terms/privacy"),
          ),
          _ConsentRow(
            label: "위치기반 서비스 이용약관 동의",
            required: true,
            value: _consents["location"]!,
            onChanged: (value) => setState(() => _consents["location"] = value),
            onView: () => context.push("/terms/location"),
          ),
          _ConsentRow(
            label: "마케팅 정보 수신 동의",
            required: false,
            value: _consents["marketing"]!,
            onChanged: (value) =>
                setState(() => _consents["marketing"] = value),
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    // §9.2 상태를 색으로만 구분하지 않는다 — 아이콘과 텍스트를 같이 둔다.
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: EnsomColors.limeSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 12, color: EnsomColors.limeInk),
              SizedBox(width: 4),
              Text(
                "이메일 인증 완료",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: EnsomColors.limeInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.label,
    required this.required,
    required this.value,
    required this.onChanged,
    this.onView,
  });

  final String label;
  final bool required;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => onChanged(!value),
            child: Padding(
              // §9.4 최소 44px 히트 영역 — 체크박스가 시각적으로 작아서
              // 패딩으로 넓힌다.
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                children: [
                  Icon(
                    value ? Icons.check_circle : Icons.circle_outlined,
                    size: 20,
                    color: value ? EnsomColors.cta : EnsomColors.hairline,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      required ? "[필수] $label" : "[선택] $label",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: value ? EnsomColors.ink : EnsomColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onView != null)
          TextButton(
            onPressed: onView,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: EnsomColors.inkMuted,
              textStyle: const TextStyle(
                fontSize: 11.5,
                decoration: TextDecoration.underline,
              ),
            ),
            child: const Text("보기"),
          ),
      ],
    );
  }
}

class _PasswordCheck extends StatelessWidget {
  const _PasswordCheck({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: ok ? EnsomColors.cta : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: ok ? EnsomColors.cta : EnsomColors.hairline,
                width: 1.6,
              ),
            ),
            child: ok
                ? const Icon(Icons.check, size: 11, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ok ? EnsomColors.ink : EnsomColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
