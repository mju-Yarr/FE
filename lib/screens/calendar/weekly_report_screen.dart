import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";
import "../../models/weekly_summary.dart";
import "../../providers/calendar_providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_skeleton.dart";

/// CAL-06. 서버의 주간 집계를 그대로 표시하며 표본 없음(null)과 실제 0을
/// 구분한다. 서버가 제공하지 않는 도착 분류별 횟수는 추정하지 않는다.
class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  late DateTime _anchorDate;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _anchorDate = DateTime(initial.year, initial.month, initial.day);
  }

  void _shiftWeek(int weeks) {
    setState(() => _anchorDate = _anchorDate.add(Duration(days: weeks * 7)));
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(weeklySummaryProvider(_anchorDate));
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onBack: context.pop,
              onPrevious: () => _shiftWeek(-1),
              onNext: () => _shiftWeek(1),
            ),
            Expanded(
              child: summary.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _ErrorState(
                  onRetry: () =>
                      ref.invalidate(weeklySummaryProvider(_anchorDate)),
                ),
                data: (value) => _ReportBody(summary: value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
  });

  final VoidCallback onBack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      child: Row(
        children: [
          _CircleButton(icon: Icons.chevron_left, onTap: onBack),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "주간 리포트",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: EnsomColors.ink,
              ),
            ),
          ),
          IconButton(
            tooltip: "이전 주",
            onPressed: onPrevious,
            icon: const Icon(Icons.arrow_back_ios_new, size: 15),
          ),
          IconButton(
            tooltip: "다음 주",
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward_ios, size: 15),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: EnsomColors.surface2,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 17, color: EnsomColors.ink),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.summary});

  final WeeklySummary summary;

  String get _dateRange {
    final start = DateFormat("M월 d일").format(summary.weekStart);
    final end = DateFormat("M월 d일").format(summary.weekEnd);
    return "$start – $end";
  }

  String get _onTime {
    final rate = summary.onTimeRate;
    return rate == null ? "—" : "${(rate * 100).round()}%";
  }

  String get _slack {
    final minutes = summary.averageSlackMinutes;
    if (minutes == null) return "—";
    return minutes > 0 ? "+$minutes분" : "$minutes분";
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 48),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: EnsomColors.ink,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: EnsomColors.lime,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  "이번 주 리포트",
                  style: TextStyle(
                    color: EnsomColors.ink,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _dateRange,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _StatBox(
                    label: "관리 일정",
                    value: "${summary.managedEventCount}개",
                  ),
                  _StatBox(label: "정시 도착", value: _onTime),
                  _StatBox(label: "평균 여유", value: _slack),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PrepAccuracyCard(points: summary.prepAccuracy),
        const SizedBox(height: 12),
        _WellnessCard(summary: summary),
        const SizedBox(height: 12),
        _OutdoorCard(summary: summary),
        const SizedBox(height: 12),
        // §3 S-15 "리포트가 막다른 화면이 되지 않도록 개별 일정으로 들어가는
        // 경로를 반드시 둔다." 주간 요약 API에는 일정 목록이 없어 같은 주
        // 범위의 일정을 따로 읽는다.
        _WeekEventsCard(weekStart: summary.weekStart, weekEnd: summary.weekEnd),
      ],
    );
  }
}

/// 이번 주 일정 리스트. 행을 누르면 S-12 상세로 간다.
class _WeekEventsCard extends ConsumerWidget {
  const _WeekEventsCard({required this.weekStart, required this.weekEnd});

  final DateTime weekStart;
  final DateTime weekEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = EventRange(
      from: DateTime(weekStart.year, weekStart.month, weekStart.day),
      to: DateTime(
        weekEnd.year,
        weekEnd.month,
        weekEnd.day,
      ).add(const Duration(days: 1)),
    );
    final events = ref.watch(eventsInRangeProvider(range)).value;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: EnsomColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EnsomColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "이번 주 일정",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -.2,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (events == null)
            const EnsomSkeletonList(count: 3, itemHeight: 40)
          else if (events.isEmpty)
            const Text(
              "이번 주에 관리한 일정이 없어요.",
              style: TextStyle(fontSize: 11.5, color: EnsomColors.inkFaint),
            )
          else
            for (final event in events)
              InkWell(
                onTap: () => context.push("/events/${event.eventId}"),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Text(
                        DateFormat(
                          "M/d HH:mm",
                        ).format(event.startsAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: EnsomColors.inkMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          event.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: EnsomColors.ink,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 15,
                        color: EnsomColors.inkFaint,
                      ),
                    ],
                  ),
                ),
              ),
        ],
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
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .58),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrepAccuracyCard extends StatelessWidget {
  const _PrepAccuracyCard({required this.points});

  final List<PrepAccuracyPoint> points;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: "준비 시간 추이",
      subtitle: "예측과 실제 준비 시간을 비교해요",
      child: points.isEmpty
          ? const _EmptyMetric(message: "준비 기록이 아직 없어요")
          : Column(
              children: [
                SizedBox(
                  height: 116,
                  width: double.infinity,
                  child: CustomPaint(painter: _PrepChartPainter(points)),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _LegendDot(color: EnsomColors.inkMuted, label: "예측"),
                    SizedBox(width: 12),
                    _LegendDot(color: EnsomColors.cta, label: "실제"),
                  ],
                ),
              ],
            ),
    );
  }
}

class _WellnessCard extends StatelessWidget {
  const _WellnessCard({required this.summary});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final rate = summary.wellnessCompletionRate;
    return _CardShell(
      title: "웰니스 행동",
      subtitle: rate == null
          ? "이번 주에 제안된 행동이 없어요"
          : "${summary.wellnessProposedCount}개 중 ${summary.wellnessCompletedCount}개 완료",
      child: rate == null
          ? const _EmptyMetric(message: "다음 이동에서 필요한 행동을 알려드릴게요")
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${(rate * 100).round()}%",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: EnsomColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: rate.clamp(0, 1),
                    backgroundColor: EnsomColors.surface2,
                    color: EnsomColors.cta,
                  ),
                ),
              ],
            ),
    );
  }
}

class _OutdoorCard extends StatelessWidget {
  const _OutdoorCard({required this.summary});

  final WeeklySummary summary;

  String get _duration {
    final hours = summary.outdoorMinutes ~/ 60;
    final minutes = summary.outdoorMinutes % 60;
    if (hours == 0) return "$minutes분";
    if (minutes == 0) return "$hours시간";
    return "$hours시간 $minutes분";
  }

  @override
  Widget build(BuildContext context) {
    final hasSamples = summary.outdoorSampleCount > 0;
    final source = summary.outdoorSource == "observed" ? "실측" : "예상 포함";
    return _CardShell(
      title: "야외 노출",
      subtitle: hasSamples
          ? "$source · ${summary.outdoorSampleCount}개 일정"
          : "기록 없음",
      child: hasSamples
          ? Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: EnsomColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wb_sunny_outlined,
                    color: EnsomColors.ink,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  _duration,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: EnsomColors.ink,
                  ),
                ),
              ],
            )
          : const _EmptyMetric(message: "야외 이동 기록이 아직 없어요"),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnsomColors.surface1,
        border: Border.all(color: EnsomColors.hairline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, color: EnsomColors.inkMuted),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EmptyMetric extends StatelessWidget {
  const _EmptyMetric({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      decoration: BoxDecoration(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11.5, color: EnsomColors.inkFaint),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: EnsomColors.inkMuted),
        ),
      ],
    );
  }
}

class _PrepChartPainter extends CustomPainter {
  const _PrepChartPainter(this.points);

  final List<PrepAccuracyPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final maxMinutes = points.fold<int>(
      1,
      (value, point) => math.max(
        value,
        math.max(point.predictedMinutes, point.actualMinutes),
      ),
    );
    final grid = Paint()
      ..color = EnsomColors.hairline
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    void drawSeries(Color color, int Function(PrepAccuracyPoint) valueOf) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = points.length == 1
            ? size.width / 2
            : size.width * i / (points.length - 1);
        final y =
            size.height -
            (valueOf(points[i]) / maxMinutes) * (size.height - 8) -
            4;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }

    drawSeries(EnsomColors.inkMuted, (point) => point.predictedMinutes);
    drawSeries(EnsomColors.cta, (point) => point.actualMinutes);
  }

  @override
  bool shouldRepaint(covariant _PrepChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "주간 리포트를 불러오지 못했어요.",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: EnsomColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text("다시 시도")),
          ],
        ),
      ),
    );
  }
}
