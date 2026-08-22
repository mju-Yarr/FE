import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../network/api_client.dart";
import "../../providers/auth_providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_error_banner.dart";
import "../../widgets/ensom/ensom_pill_button.dart";
import "../../widgets/ensom/ensom_text_field.dart";
import "../../widgets/ensom/ensom_top_bar.dart";

/// S-25 비밀번호 변경. ensom_account.html "v1 비밀번호 변경" 반영 —
/// 조건 체크리스트 4줄(8자 이상 대신 앱 전역 정책인 10자 이상을 씀,
/// 영문 포함, 숫자 포함, 현재 비밀번호와 다름)로 제출 버튼을 게이팅한다.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _submitting = false;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    _currentPasswordCtrl.addListener(() => setState(() {}));
    _newPasswordCtrl.addListener(() => setState(() {}));
    _confirmPasswordCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  String get _current => _currentPasswordCtrl.text;
  String get _next => _newPasswordCtrl.text;
  String get _confirm => _confirmPasswordCtrl.text;

  bool get _hasLength => _next.length >= 10;
  bool get _hasLetter => RegExp(r"[A-Za-z]").hasMatch(_next);
  bool get _hasDigit => RegExp(r"[0-9]").hasMatch(_next);
  bool get _differsFromCurrent =>
      _next.isNotEmpty && _current.isNotEmpty && _next != _current;

  bool get _confirmMatches => _confirm.isNotEmpty && _confirm == _next;

  bool get _canSubmit =>
      !_submitting &&
      _current.isNotEmpty &&
      _hasLength &&
      _hasLetter &&
      _hasDigit &&
      _differsFromCurrent &&
      _confirmMatches;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _fieldError = null;
      _submitting = true;
    });
    try {
      final api = ref.read(apiClientProvider);
      await api.patch<Map<String, dynamic>>(
        "/me/password",
        body: {
          // Google-only 계정 최초 설정 시 currentPassword 생략 (§2.4)
          if (_current.isNotEmpty) "currentPassword": _current,
          "newPassword": _next,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("비밀번호를 변경했어요.")));
        context.pop();
      }
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        setState(() => _fieldError = "네트워크에 연결할 수 없어요. 다시 시도해주세요.");
      } else if (e.code == "INVALID_PASSWORD") {
        setState(() => _fieldError = "현재 비밀번호가 일치하지 않아요.");
      } else if (e.code == "WEAK_PASSWORD") {
        setState(() => _fieldError = "새 비밀번호가 너무 약해요. 다른 비밀번호를 사용해주세요.");
      } else {
        setState(() => _fieldError = e.message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: const EnsomTopBar(title: "비밀번호 변경"),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                children: [
                  EnsomTextField(
                    label: "현재 비밀번호",
                    controller: _currentPasswordCtrl,
                    obscureText: true,
                    helperText: "Google로만 가입한 경우 비워두세요",
                  ),
                  const Divider(height: 30, color: EnsomColors.hairline),
                  EnsomTextField(
                    label: "새 비밀번호",
                    controller: _newPasswordCtrl,
                    obscureText: true,
                  ),
                  const SizedBox(height: 14),
                  EnsomTextField(
                    label: "새 비밀번호 확인",
                    controller: _confirmPasswordCtrl,
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                    helperText: _confirm.isEmpty
                        ? null
                        : (_confirmMatches ? "비밀번호가 일치해요" : "비밀번호가 일치하지 않아요"),
                    helperTone: _confirmMatches
                        ? EnsomFieldTone.ok
                        : EnsomFieldTone.bad,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CheckLine(label: "10자 이상", ok: _hasLength),
                        _CheckLine(label: "영문 포함", ok: _hasLetter),
                        _CheckLine(label: "숫자 포함", ok: _hasDigit),
                        _CheckLine(
                          label: "현재 비밀번호와 다름",
                          ok: _differsFromCurrent,
                        ),
                      ],
                    ),
                  ),
                  if (_fieldError != null) ...[
                    const SizedBox(height: 14),
                    EnsomErrorBanner(title: _fieldError!),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    "비밀번호를 변경하면 다른 기기에서는 다시 로그인해야 해요",
                    style: TextStyle(
                      fontSize: 10.5,
                      color: EnsomColors.inkFaint,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: const BoxDecoration(
                color: EnsomColors.surface1,
                border: Border(top: BorderSide(color: EnsomColors.hairline)),
              ),
              child: EnsomPillButton(
                label: _submitting ? "변경 중..." : "변경하기",
                onPressed: _canSubmit ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: ok ? EnsomColors.cta : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: ok ? EnsomColors.cta : EnsomColors.hairline,
                width: 1.7,
              ),
            ),
            child: ok
                ? const Icon(Icons.check, size: 11, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ok ? EnsomColors.ink : EnsomColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}
