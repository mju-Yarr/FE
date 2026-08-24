import "dart:async";

import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:google_sign_in/google_sign_in.dart" show GoogleSignInAccount;
import "../../core/app_config.dart";
import "../../core/google_auth_helper.dart";
import "../../core/google_id_token.dart";
import "../../core/google_web_button/google_web_button.dart";
import "../../network/api_client.dart";
import "../../providers/auth_providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_pill_button.dart";
import "../../widgets/ensom/ensom_wordmark.dart";
import "consent_detail_screen.dart";
import "email_signup_screen.dart";
import "email_login_screen.dart";
import "support_screen.dart";

enum _AuthNotice { none, cancelled, network, provider }

/// S-01 진입 선택 화면. API 명세 §2.5 POST /auth/login (Google)
/// Google 로그인은 idToken을 서버에 보내면 서버가 계정 확정·세션 발급.
/// Google 로그인은 항상 emailVerificationRequired: false (§2.5).
///
/// ensom_auth.html 목업의 "화면1 로그인"·"화면2 오류" 스타일을 반영한다.
/// 목업의 이메일 인라인 폼(이메일+비밀번호를 이 화면에서 바로 입력)은
/// 프로토타입 단순화였을 뿐 실제 가입 흐름과 안 맞아서(가입엔 더 많은
/// 정보가 필요) 적용하지 않고, 기존처럼 EmailSignupScreen으로 이동한다.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _submitting = false;
  _AuthNotice _notice = _AuthNotice.none;
  String? _errorDetail;
  StreamSubscription<GoogleSignInAccount?>? _webGoogleSub;

  @override
  void initState() {
    super.initState();
    // 웹은 GSI가 직접 그리는 버튼(google_web_button.dart)을 쓴다 —
    // signIn()과 달리 결과가 Future 반환값이 아니라 이 스트림으로 온다.
    if (kIsWeb && kGoogleServerClientId.isNotEmpty) {
      _webGoogleSub = GoogleAuthHelper.instance.onLoginUserChanged.listen(
        _handleWebGoogleAccount,
      );
      // renderButton()이 실제 버튼을 그리려면 GIS 초기화가 먼저 끝나야
      // 한다 — 안 하면 "Getting ready" 텍스트만 계속 보인다.
      unawaited(GoogleAuthHelper.instance.ensureWebLoginReady());
    }
  }

  @override
  void dispose() {
    _webGoogleSub?.cancel();
    super.dispose();
  }

  Future<void> _handleWebGoogleAccount(GoogleSignInAccount? account) async {
    if (account == null || _submitting) return;
    setState(() {
      _submitting = true;
      _notice = _AuthNotice.none;
    });
    try {
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw StateError("Google 인증에서 idToken을 가져오지 못했습니다.");
      }
      await _validateGoogleToken(idToken);
      await _completeLogin(idToken);
    } on ApiException catch (e) {
      debugPrint("[google-login] 실패(ApiException): ${e.code} ${e.message}");
      if (e.code == "INVALID_GOOGLE_TOKEN") {
        await GoogleAuthHelper.instance.clearLoginSession();
      }
      setState(() {
        _notice = e.code == "NETWORK_ERROR"
            ? _AuthNotice.network
            : _AuthNotice.provider;
        _errorDetail = null;
      });
    } catch (e, st) {
      debugPrint("[google-login] 실패: $e\n$st");
      setState(() {
        _notice = _AuthNotice.provider;
        _errorDetail = null;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 모바일 전용 — 네이티브 채널 기반이라 deprecated 아니고 팝업/user-
  /// activation 문제도 없다. 웹은 initState의 스트림 구독으로 처리한다.
  Future<void> _handleGoogleLogin() async {
    setState(() {
      _submitting = true;
      _notice = _AuthNotice.none;
    });
    try {
      final idToken = await GoogleAuthHelper.instance.signInForLogin();
      if (idToken == null) {
        // 사용자가 취소
        setState(() {
          _submitting = false;
          _notice = _AuthNotice.cancelled;
        });
        return;
      }
      await _validateGoogleToken(idToken);
      await _completeLogin(idToken);
    } on ApiException catch (e) {
      debugPrint("[google-login] 실패(ApiException): ${e.code} ${e.message}");
      if (e.code == "INVALID_GOOGLE_TOKEN") {
        await GoogleAuthHelper.instance.clearLoginSession();
      }
      setState(() {
        _notice = e.code == "NETWORK_ERROR"
            ? _AuthNotice.network
            : _AuthNotice.provider;
        _errorDetail = null;
      });
    } catch (e, st) {
      debugPrint("[google-login] 실패: $e\n$st");
      setState(() {
        _notice = _AuthNotice.provider;
        _errorDetail = null;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _validateGoogleToken(String idToken) async {
    final problem = validateGoogleIdToken(
      idToken: idToken,
      expectedAudience: kGoogleServerClientId,
    );
    if (problem == null) return;

    await GoogleAuthHelper.instance.clearLoginSession();
    debugPrint("[google-login] rejected local token: ${problem.name}");
    throw StateError("Google 로그인 세션을 새로 인증해야 합니다.");
  }

  Future<void> _completeLogin(String idToken) async {
    final installationId = await ref.read(secureStorageProvider).installationId;
    final authNotifier = ref.read(authNotifierProvider.notifier);
    await authNotifier.loginWithGoogle(
      idToken: idToken,
      installationId: installationId,
    );

    if (!mounted) return;

    final authState = ref.read(authNotifierProvider);
    switch (authState.status) {
      case AuthStatus.consentRequired:
        context.go("/onboarding/consent");
      case AuthStatus.onboarding:
        context.go("/onboarding/prep-time");
      case AuthStatus.authenticated:
        context.go("/home");
      default:
        // Google 로그인은 emailVerificationRequired가 되지 않음
        context.go("/home");
    }
  }

  void _openPrivacyPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ConsentDetailScreen(
          consentType: "privacy",
          title: "개인정보 처리방침",
        ),
      ),
    );
  }

  void _openSupport() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SupportScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 52),
              Center(
                child: Column(
                  children: [
                    const EnsomWordmark(fontSize: 26),
                    const SizedBox(height: 12),
                    const Text(
                      "늦지 않게, 서두르지 않게.",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: EnsomColors.inkMuted,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        "다음 일정까지, 언제부터 준비하면 되는지 알려드려요.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: EnsomColors.inkFaint,
                          height: 1.6,
                          letterSpacing: -.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_notice == _AuthNotice.cancelled)
                const _QuietNote(text: "로그인이 취소됐어요. 다시 시도해 주세요."),
              if (_notice == _AuthNotice.network)
                _ErrorBanner(
                  caution: false,
                  title: "연결을 확인해 주세요",
                  subtitle: "네트워크가 불안정한 것 같아요",
                  onRetry: (_submitting || kIsWeb) ? null : _handleGoogleLogin,
                ),
              if (_notice == _AuthNotice.provider)
                _ErrorBanner(
                  caution: true,
                  title: "Google 로그인에 문제가 생겼어요",
                  subtitle: _errorDetail == null
                      ? "잠시 후 다시 시도하거나 다른 방법으로 로그인해 주세요"
                      : _errorDetail!,
                  // 웹은 재시도가 함수 호출이 아니라 아래 구글 버튼을
                  // 다시 클릭하는 것이라 onRetry를 안 둔다.
                  onRetry: (_submitting || kIsWeb) ? null : _handleGoogleLogin,
                ),
              if (_notice != _AuthNotice.none) const SizedBox(height: 4),
              Column(
                children: [
                  EnsomPillButton(
                    label: "이메일로 계속하기",
                    icon: const Icon(
                      Icons.mail_outline,
                      size: 18,
                      color: Colors.white,
                    ),
                    onPressed: _submitting
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EmailSignupScreen(),
                              ),
                            );
                          },
                  ),
                  const SizedBox(height: 10),
                  if (kGoogleServerClientId.isNotEmpty)
                    if (kIsWeb)
                      buildGoogleWebButton()
                    else
                      _GoogleButton(
                        loading: _submitting,
                        onPressed: _handleGoogleLogin,
                      ),
                ],
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EmailLoginScreen(),
                          ),
                        );
                      },
                child: const Text(
                  "이미 계정이 있으신가요? 로그인",
                  style: TextStyle(fontSize: 12.5, color: EnsomColors.inkMuted),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _openPrivacyPolicy,
                    child: const Text(
                      "개인정보 처리방침",
                      style: TextStyle(
                        fontSize: 11,
                        color: EnsomColors.inkFaint,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      "·",
                      style: TextStyle(
                        fontSize: 11,
                        color: EnsomColors.hairline,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _openSupport,
                    child: const Text(
                      "고객지원",
                      style: TextStyle(
                        fontSize: 11,
                        color: EnsomColors.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: EnsomColors.hairline)),
      child: InkWell(
        onTap: loading ? null : onPressed,
        customBorder: StadiumBorder(
          side: BorderSide(color: EnsomColors.hairline),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.g_mobiledata,
                size: 26,
                color: Color(0xFF4285F4),
              ),
              const SizedBox(width: 4),
              Text(
                "Google로 계속하기",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.2,
                  color: EnsomColors.ink.withValues(alpha: loading ? .4 : 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuietNote extends StatelessWidget {
  const _QuietNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          color: EnsomColors.inkMuted,
          height: 1.6,
          letterSpacing: -.2,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.caution,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final bool caution;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: caution ? const Color(0xFFFAF0DD) : EnsomColors.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: caution
                  ? EnsomColors.caution
                  : EnsomColors.inkFaint.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                    color: EnsomColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: EnsomColors.inkMuted,
                    height: 1.5,
                    letterSpacing: -.2,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: EnsomColors.ink,
              minimumSize: Size.zero,
              padding: const EdgeInsets.only(left: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              "다시 시도",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
