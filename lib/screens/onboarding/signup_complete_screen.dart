import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../providers/auth_providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_pill_button.dart";

/// S-18 가입 완료. ensom_signup.html 목업 "화면3 가입 완료"를 반영.
/// BE 이메일 링크 방식 기준: 이메일 인증 후 사용자가 앱에서 로그인하면
/// BE가 isNew=true를 반환한다. 로그인 분기에서 이 화면으로 보내고,
/// [시작하기]를 누르면 S-03 준비 시간 온보딩으로 진행한다.
/// 뒤로가기는 차단된다 — 가입 이전으로 돌아갈 수 없다.
class SignupCompleteScreen extends ConsumerWidget {
  const SignupCompleteScreen({super.key});

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
                  "가입이 완료됐어요",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.45,
                    color: EnsomColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "이제 준비 시간을 설정하면\n첫 준비 계획을 만들어 드릴게요.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: EnsomColors.inkMuted,
                    height: 1.65,
                  ),
                ),
                const Spacer(flex: 4),
                EnsomPillButton(
                  label: "시작하기",
                  onPressed: () {
                    ref
                        .read(authNotifierProvider.notifier)
                        .advanceOnboarding("prep");
                    context.go("/onboarding/prep-time");
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
