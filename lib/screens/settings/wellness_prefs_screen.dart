import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_riverpod/legacy.dart";
import "../../models/wellness_pref.dart";
import "../../repository/ensom_repository.dart";
import "../../repository/providers.dart";
import "../../theme/ensom_colors.dart";
import "../../theme/wellness_topic_copy.dart";
import "../../widgets/ensom/ensom_toggle.dart";
import "../../widgets/ensom/ensom_top_bar.dart";

final wellnessPrefsProvider =
    StateNotifierProvider.autoDispose<
      WellnessPrefsController,
      AsyncValue<List<WellnessPref>>
    >((ref) {
      final repo = ref.watch(ensomRepositoryProvider);
      return WellnessPrefsController(repo);
    });

class WellnessPrefsController
    extends StateNotifier<AsyncValue<List<WellnessPref>>> {
  WellnessPrefsController(this._repo) : super(const AsyncValue.loading()) {
    _load();
  }

  final EnsomRepository _repo;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await _repo.fetchWellnessPrefs();
      state = AsyncValue.data(prefs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> update(WellnessPref updated) async {
    final prefs = state.value;
    if (prefs == null) return;
    final newList = [
      for (final p in prefs)
        if (p.topic == updated.topic) updated else p,
    ];
    state = AsyncValue.data(newList);
    try {
      await _repo.updateWellnessPrefs(newList);
    } catch (_) {
      state = AsyncValue.data(prefs); // 롤백
    }
  }
}

/// ensom_profile.html "5. 웰니스" 화면(관심 환경 항목 부분)을 반영.
/// 목업엔 "선크림 재도포 리마인드"·"일정 중 알림" 전용 섹션도 있지만,
/// 그건 UV 항목 하나에만 해당하는 별도 기능이고 우리 WellnessPref
/// 모델엔 topic별 remindIntervalMinutes만 있어서(선크림 전용 필드가
/// 없음) 이미 있는 재알림 주기 슬라이더로 대체했다.
class WellnessPrefsScreen extends ConsumerWidget {
  const WellnessPrefsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(wellnessPrefsProvider);
    final controller = ref.read(wellnessPrefsProvider.notifier);

    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: const EnsomTopBar(title: "웰니스 관심 항목"),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => const Center(
          child: Text(
            "불러오지 못했어요.",
            style: TextStyle(color: EnsomColors.inkMuted),
          ),
        ),
        data: (prefs) => SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              const Text(
                "관심 환경 항목",
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: EnsomColors.inkFaint,
                  letterSpacing: .4,
                ),
              ),
              const SizedBox(height: 4),
              for (final pref in prefs)
                _PrefTile(pref: pref, onChanged: controller.update),
              const SizedBox(height: 12),
              const Text(
                "재알림 주기는 사용자가 직접 설정해요. 환경과 개인 상태에 따라 달라질 수 있어 앱이 대신 판단하지 않아요.",
                style: TextStyle(
                  fontSize: 11,
                  color: EnsomColors.inkFaint,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({required this.pref, required this.onChanged});

  final WellnessPref pref;
  final void Function(WellnessPref) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: EnsomColors.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EnsomColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => onChanged(pref.copyWith(isEnabled: !pref.isEnabled)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    wellnessTopicLabels[pref.topic] ?? pref.topic,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: EnsomColors.ink,
                    ),
                  ),
                ),
                EnsomToggle(
                  value: pref.isEnabled,
                  onChanged: (v) => onChanged(pref.copyWith(isEnabled: v)),
                ),
              ],
            ),
          ),
          if (pref.isEnabled) ...[
            const SizedBox(height: 6),
            Text(
              "재알림 주기: ${pref.remindIntervalMinutes ?? 120}분",
              style: const TextStyle(
                fontSize: 11.5,
                color: EnsomColors.inkMuted,
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: EnsomColors.cta,
                inactiveTrackColor: EnsomColors.surface2,
                thumbColor: EnsomColors.cta,
                overlayColor: EnsomColors.cta.withValues(alpha: .12),
                trackHeight: 3,
              ),
              child: Slider(
                value: (pref.remindIntervalMinutes ?? 120).toDouble(),
                min: 30,
                max: 240,
                divisions: 14,
                onChanged: (v) =>
                    onChanged(pref.copyWith(remindIntervalMinutes: v.round())),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
