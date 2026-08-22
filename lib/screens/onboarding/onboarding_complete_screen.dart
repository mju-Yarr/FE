import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../providers/auth_providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_pill_button.dart";

/// S-42 온보딩 완료. 이전 단계로 돌아갈 수 없으며 시작하기로 상태를 확정한다.
/// ensom_onboarding_flow.html STEP 8("준비됐어요")의 라임 원형 체크
/// 아이콘 + 헤드라인 + 알약 버튼 패턴을 반영한다.
class OnboardingCompleteScreen extends ConsumerWidget {
  const OnboardingCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: EnsomColors.canvas,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 18),
            child: Column(
              children: [
                const Spacer(flex: 3),
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: EnsomColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 32, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  "준비됐어요",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.4,
                    color: EnsomColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "이제 일정을 추가하면 언제부터\n준비해야 할지 알려드릴게요.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: EnsomColors.inkMuted,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "설정은 언제든 프로필에서 변경할 수 있어요.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: EnsomColors.inkFaint),
                ),
                const Spacer(flex: 4),
                EnsomPillButton(
                  label: "시작하기",
                  onPressed: () async {
                    await ref
                        .read(authNotifierProvider.notifier)
                        .onOnboardingCompleted();
                    if (context.mounted) context.go("/home");
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
