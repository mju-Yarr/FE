import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";
import "../../models/daily_wellness_summary.dart";
import "../../repository/providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_top_bar.dart";

final dailySummaryProvider = FutureProvider.autoDispose
    .family<DailyWellnessSummary?, DateTime>((ref, date) async {
      final repo = ref.watch(ensomRepositoryProvider);
      final dateStr = DateFormat("yyyy-MM-dd").format(date);
      return repo.fetchDailySummary(dateStr);
    });

class DailySummaryScreen extends ConsumerStatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  ConsumerState<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends ConsumerState<DailySummaryScreen> {
  bool _viewedMarked = false;

  Color _bandColor(DwlBand band) {
    switch (band) {
      case DwlBand.low:
        return EnsomColors.limeInk;
      case DwlBand.mid:
        return EnsomColors.caution;
      case DwlBand.high:
        return EnsomColors.caution;
    }
  }

  String _bandLabel(DwlBand band) {
    switch (band) {
      case DwlBand.low:
        return "낮음";
      case DwlBand.mid:
        return "보통";
      case DwlBand.high:
        return "높음";
    }
  }

  /// isViewed==false일 때 화면 진입 시 1회 POST /summary/daily/{id}/viewed 호출.
  void _markViewedIfNeeded(DailyWellnessSummary summary) {
    if (_viewedMarked || summary.isViewed) return;
    _viewedMarked = true;
    final repo = ref.read(ensomRepositoryProvider);
    // fire-and-forget: 조회 기록 실패가 화면을 막아서는 안 됨
    repo.markDailySummaryViewed(summary.summaryId);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final summaryAsync = ref.watch(dailySummaryProvider(today));

    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: const EnsomTopBar(title: "오늘의 마무리"),
      body: SafeArea(
        top: false,
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => const Center(
            child: Text(
              "불러오지 못했어요.",
              style: TextStyle(color: EnsomColors.inkMuted),
            ),
          ),
          data: (summary) {
            // 관리 일정 0건이면 서버가 카드를 안 만들어준다 -- 숫자를
            // 지어내지 않고 데이터 없음 상태를 그대로 보여준다 (PRD §14.8).
            if (summary == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    "오늘은 아직 관리된 일정이 없어요.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: EnsomColors.inkFaint,
                    ),
                  ),
                ),
              );
            }
            // 화면 진입 시 조회 기록 (§12.4 POST /summary/daily/{id}/viewed)
            _markViewedIfNeeded(summary);
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _bandColor(summary.dwlBand),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "오늘의 웰니스 노출 — ${_bandLabel(summary.dwlBand)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.2,
                          color: EnsomColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: EnsomColors.surface2,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: "관리된 일정",
                          value: "${summary.eventCount}개",
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: EnsomColors.hairline,
                      ),
                      Expanded(
                        child: _StatBox(
                          label: "야외 이동",
                          value: "${summary.totalOutdoorMinutes}분",
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // 서버가 완성한 문구를 그대로 표시 (TR-09). 개인 특이사항·
                // 복용약 관련 내용은 이 카드 생성 입력에서 원천 배제된
                // 문구다 (PRD §14.8) -- 클라이언트가 재구성하지 않는다.
                Text(
                  summary.message,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: EnsomColors.ink,
                    height: 1.6,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -.3,
            color: EnsomColors.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: EnsomColors.inkFaint),
        ),
      ],
    );
  }
}
