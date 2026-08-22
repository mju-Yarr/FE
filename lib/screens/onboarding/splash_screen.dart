import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../providers/auth_providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_wordmark.dart";

/// S-37. 앱을 켤 때마다 뜨는 화면(온보딩 단계 아님). 라임 배경이 화면을
/// 꽉 채우고, 워드마크 O 자리의 링이 도는 것 자체가 로딩 인디케이터다
/// — 별도 스피너를 두지 않는다(§1.1). 최소 노출 시간 1.5초를 지켜서
/// 세션 검사가 빨리 끝나도 화면이 깜빡이지 않게 한다.
///
/// 네트워크 오류로 세션 검사에 실패하면 로그인 화면으로 보내지 않고
/// 이 화면에 머물며 재시도 안내를 띄운다(§1.1, §13-4).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _minDisplayElapsed = false;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _minDisplayElapsed = true);
    });
  }

  Future<void> _retry() async {
    setState(() => _isRetrying = true);
    await ref.read(authNotifierProvider.notifier).retrySessionCheck();
    if (mounted) setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    // 최소 노출 시간이 지나기 전까지는 세션 검사 실패 안내도 미루고
    // 링 애니메이션만 보여준다 — 화면이 깜빡이는 걸 막기 위함.
    final showRetry =
        _minDisplayElapsed && authState.status == AuthStatus.sessionCheckFailed;

    return Scaffold(
      backgroundColor: EnsomColors.lime,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EnsomWordmark(fontSize: 40, animate: true),
            const SizedBox(height: 16),
            Text(
              "늦지 않게, 서두르지 않게.",
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -.2,
                color: EnsomColors.ink.withValues(alpha: .60),
              ),
            ),
            if (showRetry) ...[
              const SizedBox(height: 28),
              Text(
                authState.errorMessage ?? "연결을 확인하지 못했어요.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: EnsomColors.ink.withValues(alpha: .72),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isRetrying ? null : _retry,
                style: TextButton.styleFrom(foregroundColor: EnsomColors.ink),
                child: Text(_isRetrying ? "다시 확인하는 중..." : "다시 시도"),
              ),
              TextButton(
                onPressed: _isRetrying
                    ? null
                    : () async {
                        setState(() => _isRetrying = true);
                        await ref
                            .read(authNotifierProvider.notifier)
                            .discardLocalSession();
                        if (mounted) setState(() => _isRetrying = false);
                      },
                style: TextButton.styleFrom(
                  foregroundColor: EnsomColors.ink.withValues(alpha: .68),
                ),
                child: const Text("다시 로그인"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
