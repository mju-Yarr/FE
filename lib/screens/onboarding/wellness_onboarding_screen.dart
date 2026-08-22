import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../models/wellness_pref.dart";
import "../../providers/auth_providers.dart";
import "../settings/wellness_prefs_screen.dart";
import "../../theme/ensom_colors.dart";
import "../../theme/wellness_topic_copy.dart";
import "../../widgets/ensom/ensom_pill_button.dart";
import "../../widgets/ensom/ensom_toggle.dart";

/// ONB-06 웰니스 관심 항목 설정 (온보딩 context)
/// 기존 WellnessPrefsScreen의 provider를 재사용하되,
/// AppBar에 [완료]/[건너뛰기]를 추가해 /home으로 이동한다.
///
/// ensom_onboarding_flow.html STEP 7의 h1/sub + 토글 리스트 레이아웃을
/// 반영한다(아이콘 없이 제목·설명·토글만 있는 단순 행).
class WellnessOnboardingScreen extends ConsumerWidget {
  const WellnessOnboardingScreen({super.key});

  void _finish(WidgetRef ref, BuildContext context) {
    ref.read(authNotifierProvider.notifier).advanceOnboarding("wellness");
    context.go("/onboarding/complete");
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(wellnessPrefsProvider);
    final controller = ref.read(wellnessPrefsProvider.notifier);

    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: AppBar(
        backgroundColor: EnsomColors.canvas,
        surfaceTintColor: EnsomColors.canvas,
        elevation: 0,
        title: const Text(
          "웰니스 관심 항목",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: EnsomColors.ink,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _finish(ref, context),
            child: const Text(
              "건너뛰기",
              style: TextStyle(fontSize: 13, color: EnsomColors.inkMuted),
            ),
          ),
        ],
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "불러오지 못했어요: $err",
                style: const TextStyle(color: EnsomColors.inkMuted),
              ),
              const SizedBox(height: 14),
              EnsomPillButton(
                label: "건너뛰고 시작하기",
                expand: false,
                onPressed: () => _finish(ref, context),
              ),
            ],
          ),
        ),
        data: (prefs) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                children: [
                  const Text(
                    "관심 있는 환경 정보가 있나요?",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.3,
                      color: EnsomColors.ink,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    "선택한 항목만 준비 제안에 반영돼요. 지금 설정하지 않아도 핵심 기능은 그대로 동작해요.",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: EnsomColors.inkMuted,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final pref in prefs)
                    _WellnessPrefRow(pref: pref, onChanged: controller.update),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: EnsomPillButton(
                label: "완료",
                onPressed: () => _finish(ref, context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WellnessPrefRow extends StatelessWidget {
  const _WellnessPrefRow({required this.pref, required this.onChanged});

  final WellnessPref pref;
  final void Function(WellnessPref) onChanged;

  @override
  Widget build(BuildContext context) {
    final subtitle = wellnessTopicSubtitles[pref.topic];
    return InkWell(
      onTap: () => onChanged(pref.copyWith(isEnabled: !pref.isEnabled)),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wellnessTopicLabels[pref.topic] ?? pref.topic,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: EnsomColors.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: EnsomColors.inkFaint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            EnsomToggle(
              value: pref.isEnabled,
              onChanged: (v) => onChanged(pref.copyWith(isEnabled: v)),
            ),
          ],
        ),
      ),
    );
  }
}
