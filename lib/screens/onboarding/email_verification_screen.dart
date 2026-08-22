import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../network/api_client.dart";
import "../../providers/auth_providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_pill_button.dart";
import "../../widgets/ensom/ensom_top_bar.dart";

/// 이메일 회원가입 직후 진입. Google 로그인 사용자는 이 화면을 거치지 않는다.
/// API 명세 §2.3: POST /auth/email/verify/resend (재발송, 60초 쿨다운)
/// 인증 링크는 브라우저에서 검증되고, 사용자는 앱으로 돌아와 로그인해 세션을 받는다.
///
/// ensom_signup.html 목업은 인증코드를 화면 안에서 직접 입력받지만
/// (§2.3과 달리) 이 API는 링크 클릭 방식이라 코드 입력 UI를 넣지
/// 않았다 — 대신 목업의 "메일 보냈어요" 확인 화면 스타일을 썼다.
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _resending = false;
  String? _message;
  bool _messageIsError = false;
  DateTime? _lastResendAt;

  Future<void> _resendEmail() async {
    // 60초 쿨다운 (§2.3)
    if (_lastResendAt != null &&
        DateTime.now().difference(_lastResendAt!) <
            const Duration(seconds: 60)) {
      setState(() {
        _message = "60초 후에 다시 시도할 수 있어요.";
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _resending = true;
      _message = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      await authService.resendVerification(widget.email);
      _lastResendAt = DateTime.now();
      if (!mounted) return;
      setState(() {
        _message = "인증 메일을 다시 보냈어요.";
        _messageIsError = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // TR-14: 계정 유무와 무관하게 항상 200 반환이므로 에러면 네트워크 문제
      setState(() {
        _message = e.retryable
            ? "네트워크에 연결할 수 없어요. 잠시 후 다시 시도해주세요."
            : "메일 재발송에 실패했어요.";
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = "메일 재발송에 실패했어요. 잠시 후 다시 시도해주세요.";
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  /// 이메일 링크 인증은 브라우저의 GET /auth/email/verify에서 완료된다.
  /// 이 시점에는 세션 token이 없으므로 bootstrap을 호출하지 않고 로그인으로 보낸다.
  void _goToLogin() => context.go("/onboarding/auth");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: const EnsomTopBar(title: "이메일 인증"),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 18),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: EnsomColors.surface2,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 26,
                  color: EnsomColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.45,
                    height: 1.35,
                    color: EnsomColors.ink,
                  ),
                  children: [
                    TextSpan(text: widget.email),
                    const TextSpan(text: "로\n인증 메일을 보냈어요."),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "메일함에서 인증 링크를 눌러주세요.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: EnsomColors.inkMuted,
                  height: 1.6,
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 14),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: _messageIsError
                        ? EnsomColors.caution
                        : EnsomColors.limeInk,
                  ),
                ),
              ],
              const Spacer(),
              EnsomPillButton(label: "인증 후 로그인하기", onPressed: _goToLogin),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _resending ? null : _resendEmail,
                child: Text(
                  _resending ? "재발송 중..." : "인증 메일 다시 받기",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go("/onboarding/auth"),
                child: const Text(
                  "다른 방법으로 로그인",
                  style: TextStyle(fontSize: 11.5, color: EnsomColors.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
