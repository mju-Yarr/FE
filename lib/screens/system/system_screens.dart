import "package:flutter/material.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_pill_button.dart";

/// SYS-01~04 전면 오류·차단 화면 4종. ensom_fullscreen_errors.html 반영.
/// 공통 원칙(목업 명시): 사과 문구("죄송합니다") 금지, 경고 아이콘·
/// 느낌표·빨강 없음, 하단 탭바 없음 — 여백 위주로 담백하게.
class _SystemScreenScaffold extends StatelessWidget {
  const _SystemScreenScaffold({
    required this.icon,
    required this.title,
    required this.body,
    this.buttonLabel,
    this.buttonVariant = EnsomPillVariant.primary,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? buttonLabel;
  final EnsomPillVariant buttonVariant;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: EnsomColors.surface2,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 24, color: EnsomColors.inkMuted),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3,
                  color: EnsomColors.ink,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: EnsomColors.inkMuted,
                  height: 1.6,
                ),
              ),
              if (buttonLabel != null && onPressed != null) ...[
                const SizedBox(height: 22),
                EnsomPillButton(
                  label: buttonLabel!,
                  variant: buttonVariant,
                  expand: false,
                  onPressed: onPressed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// SYS-01 네트워크 없음
/// 전 화면 공통, 연결 끊김 감지 시 전면 차단.
/// 하단 탭 없이 전체 화면을 덮는 독립 화면.
class NetworkErrorScreen extends StatelessWidget {
  const NetworkErrorScreen({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _SystemScreenScaffold(
      icon: Icons.wifi_off,
      title: "연결을 확인해 주세요",
      body: "인터넷에 연결되면 자동으로 다시 시도할게요",
      buttonLabel: "다시 시도",
      buttonVariant: EnsomPillVariant.secondary,
      onPressed: onRetry,
    );
  }
}

/// SYS-02 세션 만료
class SessionExpiredScreen extends StatelessWidget {
  const SessionExpiredScreen({super.key, this.onLogin});

  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    return _SystemScreenScaffold(
      icon: Icons.person_outline,
      title: "다시 로그인해 주세요",
      body: "보안을 위해 로그인이 만료되었어요",
      buttonLabel: "로그인",
      onPressed: onLogin,
    );
  }
}

/// SYS-03 점검 중
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key, this.message});

  /// 점검 종료 예상 시각 등 안내 문구. 없으면 일반 문구를 보여준다
  /// (실제 예상 시각 데이터가 없는 상태에서 지어내지 않는다).
  final String? message;

  @override
  Widget build(BuildContext context) {
    return _SystemScreenScaffold(
      icon: Icons.build_outlined,
      title: "잠시 점검 중이에요",
      body: message ?? "곧 다시 이용하실 수 있어요",
    );
  }
}

/// SYS-04 업데이트 필요
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key, this.onUpdate});

  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    return _SystemScreenScaffold(
      icon: Icons.phone_iphone,
      title: "새 버전이 필요해요",
      body: "계속 사용하려면 업데이트해 주세요",
      buttonLabel: "업데이트",
      onPressed: onUpdate,
    );
  }
}
