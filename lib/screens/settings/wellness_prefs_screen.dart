import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_riverpod/legacy.dart";
import "../../models/wellness_pref.dart";
import "../../repository/ensom_repository.dart";
import "../../repository/providers.dart";
import "../../theme/ensom_colors.dart";
import "../../theme/wellness_topic_copy.dart";
import "../../widgets/ensom/ensom_chip.dart";
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

/// PATCH /me/settings의 wellnessEventEnabled(§4.1) — 일정 진행 중 웰니스
/// 이벤트 알림. wellness-prefs와 별개 엔드포인트라 별도 컨트롤러로 관리.
final wellnessEventNotiProvider =
    StateNotifierProvider.autoDispose<WellnessEventNotiController, AsyncValue<bool>>((
      ref,
    ) {
      final repo = ref.watch(ensomRepositoryProvider);
      return WellnessEventNotiController(repo);
    });

class WellnessEventNotiController extends StateNotifier<AsyncValue<bool>> {
  WellnessEventNotiController(this._repo) : super(const AsyncValue.loading()) {
    _load();
  }

  final EnsomRepository _repo;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final settings = await _repo.fetchSettings();
      state = AsyncValue.data(settings["wellnessEventEnabled"] as bool? ?? false);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> update(bool value) async {
    final prev = state.value;
    if (prev == null) return;
    state = AsyncValue.data(value);
    try {
      await _repo.updateSettings({"wellnessEventEnabled": value});
    } catch (_) {
      state = AsyncValue.data(prev); // 롤백
    }
  }
}

/// ensom_profile.html "5. 웰니스"(`#v-well`) 화면을 그대로 반영.
/// 관심 환경 항목(토글) · 선크림 재도포 리마인드(uv 전용, 토글+주기 칩) ·
/// 일정 중 알림(wellnessEventEnabled) 3개 섹션으로 구성된다.
class WellnessPrefsScreen extends ConsumerWidget {
  const WellnessPrefsScreen({super.key});

  static const _uvTopic = "uv";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(wellnessPrefsProvider);
    final prefsController = ref.read(wellnessPrefsProvider.notifier);
    final eventNotiAsync = ref.watch(wellnessEventNotiProvider);
    final eventNotiController = ref.read(wellnessEventNotiProvider.notifier);

    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: const EnsomTopBar(title: "웰니스"),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => const Center(
          child: Text(
            "불러오지 못했어요.",
            style: TextStyle(color: EnsomColors.inkMuted),
          ),
        ),
        data: (prefs) {
          WellnessPref? uvPref;
          for (final p in prefs) {
            if (p.topic == _uvTopic) uvPref = p;
          }

          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                const _SectionLabel("관심 환경 항목", topMargin: 0),
                for (final pref in prefs)
                  _TopicRow(
                    label: wellnessTopicLabels[pref.topic] ?? pref.topic,
                    value: pref.isEnabled,
                    onChanged: (v) =>
                        prefsController.update(pref.copyWith(isEnabled: v)),
                  ),
                const _Caption(
                  "입력하지 않아도 핵심 기능은 그대로 동작해요. 관심 있는 항목만 켜 두면 관련 알림·제안에 반영돼요.",
                ),

                if (uvPref != null) ...[
                  const _SectionDivider(),
                  const _SectionLabel("선크림 재도포 리마인드"),
                  _TopicRow(
                    label: "재도포 리마인드",
                    sub: "설정한 주기마다 다시 알려드려요",
                    value: uvPref.remindIntervalMinutes != null,
                    onChanged: (v) => prefsController.update(
                      uvPref!.copyWith(
                        remindIntervalMinutes: v ? 120 : null,
                      ),
                    ),
                  ),
                  if (uvPref.remindIntervalMinutes != null)
                    _ReapplyCycleCard(
                      key: ValueKey(uvPref.remindIntervalMinutes),
                      minutes: uvPref.remindIntervalMinutes!,
                      onChanged: (m) => prefsController.update(
                        uvPref!.copyWith(remindIntervalMinutes: m),
                      ),
                    ),
                  const _Caption(
                    "재도포 주기는 사용자가 직접 설정해요 — SPF, 피부 타입, 제품 성능에 따라 달라질 수 있어 앱이 대신 판단하지 않아요.",
                  ),
                ],

                const _SectionDivider(),
                const _SectionLabel("일정 중 알림"),
                _TopicRow(
                  label: "일정 진행 중 이벤트 알림",
                  sub: "기본 시간 알림과 별개로, 일정 도중 날씨 변화 등을 즉시 알려드려요",
                  value: eventNotiAsync.value ?? false,
                  onChanged: eventNotiController.update,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.topMargin = 18});

  final String text;
  final double topMargin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topMargin, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: EnsomColors.inkFaint,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 10),
      height: 1,
      color: EnsomColors.hairline,
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          color: EnsomColors.inkFaint,
          height: 1.5,
        ),
      ),
    );
  }
}

/// 목업 `.lrow` — 제목(+선택적 부제) + 토글. 토글에만 탭 핸들러가 붙는다
/// (목업도 `.toggle`에만 onclick이 있고 행 전체는 탭 대상이 아니다).
class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.label,
    this.sub,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: EnsomColors.ink,
                  ),
                ),
                if (sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      sub!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: EnsomColors.inkFaint,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          EnsomToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 목업 `.card.soft`의 재도포 주기 선택 카드. 2시간/3시간 프리셋 칩 또는
/// "직접 입력" 선택 시 분 단위 텍스트 입력으로 전환된다.
class _ReapplyCycleCard extends StatefulWidget {
  const _ReapplyCycleCard({super.key, required this.minutes, required this.onChanged});

  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  State<_ReapplyCycleCard> createState() => _ReapplyCycleCardState();
}

class _ReapplyCycleCardState extends State<_ReapplyCycleCard> {
  late bool _customMode = widget.minutes != 120 && widget.minutes != 180;
  late final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _submitCustom(String text) {
    final digits = text.replaceAll(RegExp(r"[^0-9]"), "");
    final parsed = int.tryParse(digits);
    if (parsed != null && parsed > 0) {
      widget.onChanged(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "재도포 주기",
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: EnsomColors.inkFaint,
              letterSpacing: .3,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                EnsomChip(
                  label: "2시간",
                  selected: !_customMode && widget.minutes == 120,
                  onTap: () {
                    setState(() => _customMode = false);
                    widget.onChanged(120);
                  },
                ),
                EnsomChip(
                  label: "3시간",
                  selected: !_customMode && widget.minutes == 180,
                  onTap: () {
                    setState(() => _customMode = false);
                    widget.onChanged(180);
                  },
                ),
                EnsomChip(
                  label: "직접 입력",
                  selected: _customMode,
                  onTap: () => setState(() => _customMode = true),
                ),
              ],
            ),
          ),
          if (_customMode)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: TextField(
                controller: _customController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13, color: EnsomColors.ink),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: "예: 90분",
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: EnsomColors.inkFaint,
                  ),
                  filled: true,
                  fillColor: EnsomColors.surface1,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: EnsomColors.hairline,
                      width: 1.4,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: EnsomColors.hairline,
                      width: 1.4,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: EnsomColors.cta,
                      width: 1.4,
                    ),
                  ),
                ),
                onSubmitted: _submitCustom,
                onEditingComplete: () => _submitCustom(_customController.text),
              ),
            ),
        ],
      ),
    );
  }
}
