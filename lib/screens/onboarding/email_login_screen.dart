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
import "email_signup_screen.dart";

/// API 명세 §2.2 POST /auth/email/login
/// 실패 시 AUTH_INVALID_CREDENTIALS (이메일 없음·비밀번호 불일치 구분 안 함, TR-14)
/// 연속 5회 실패 시 ACCOUNT_LOCKED (423) + retryAfterSec
class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final installationId = await ref
          .read(secureStorageProvider)
          .installationId;
      final authNotifier = ref.read(authNotifierProvider.notifier);
      await authNotifier.loginWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        installationId: installationId,
      );

      if (!mounted) return;

      // AuthNotifier가 상태를 전이시켰으므로 라우터가 리다이렉트 처리.
      // 하지만 명시적 분기도 둬서 go_router redirect가 아직 안 붙었을 때도 동작.
      final authState = ref.read(authNotifierProvider);
      switch (authState.status) {
        case AuthStatus.emailVerificationRequired:
          context.go(
            "/onboarding/email-verification?email=${Uri.encodeComponent(_emailController.text.trim())}",
          );
        case AuthStatus.consentRequired:
          context.go("/onboarding/consent");
        case AuthStatus.onboarding:
          context.go("/onboarding/prep-time");
        case AuthStatus.authenticated:
          context.go("/home");
        default:
          break;
      }
    } on ApiException catch (e) {
      setState(() {
        switch (e.code) {
          case "INVALID_CREDENTIALS":
          case "AUTH_INVALID_CREDENTIALS":
            _error = "이메일 또는 비밀번호를 확인해주세요.";
          case "ACCOUNT_LOCKED":
            _error = "로그인 시도가 너무 많아요. 잠시 후 다시 시도해주세요.";
          case "NETWORK_ERROR":
            _error = "네트워크에 연결할 수 없어요. 잠시 후 다시 시도해주세요.";
          default:
            _error = e.message;
        }
      });
    } catch (_) {
      setState(() => _error = "로그인에 실패했어요. 다시 시도해주세요.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: const EnsomTopBar(title: "로그인"),
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
                    label: "이메일",
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  EnsomTextField(
                    label: "비밀번호",
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _submitting
                          ? null
                          : () => context.push("/onboarding/password-reset"),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        "비밀번호를 잊으셨나요?",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: EnsomColors.inkMuted,
                        ),
                      ),
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
              child: Column(
                children: [
                  EnsomPillButton(
                    label: _submitting ? "로그인 중..." : "로그인",
                    onPressed: _canSubmit ? _submit : null,
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const EmailSignupScreen(),
                              ),
                            );
                          },
                    child: const Text(
                      "계정이 없으신가요? 회원가입",
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
}
