import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../models/calendar_connection.dart";
import "../../models/event.dart";
import "../../models/plan.dart";
import "../../providers/calendar_providers.dart";
import "../../theme/ensom_colors.dart";
import "ensom_chip.dart";
import "ensom_pill_button.dart";
import "ensom_text_field.dart";

/// S-45 간단 저장 시트. 지도에서 가져온 출발지·목적지·시각·선택 경로는
/// 읽기 전용 요약으로만 보여주고(PRD §10.5), 사용자가 입력하는 것은 일정
/// 이름과 저장할 캘린더뿐이다(§3 S-45).
///
/// 목업의 개인/업무/가족 같은 고정 분류가 아니라 실제로 연동된 캘린더 소스를
/// 보여준다. 쓰기 가능한 소스가 하나뿐이면 고를 게 없으므로 감춘다.
class EnsomQuickSaveSheet {
  static Future<QuickSaveResult?> show(
    BuildContext context, {
    required String destName,
    required EventAnchor anchorMode,
    required DateTime at,
    required RouteOption route,
    String? initialLabel,
  }) {
    return showModalBottomSheet<QuickSaveResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: EnsomColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => _QuickSaveSheetBody(
        destName: destName,
        anchorMode: anchorMode,
        at: at,
        route: route,
        initialLabel: initialLabel,
      ),
    );
  }
}

class QuickSaveResult {
  const QuickSaveResult.save(this.label, {this.calendarSourceId})
    : detailedEdit = false;

  const QuickSaveResult.detailedEdit(this.label, {this.calendarSourceId})
    : detailedEdit = true;

  final String? label;
  final bool detailedEdit;

  /// 저장할 캘린더. null이면 서버가 기본 기록 캘린더를 쓴다.
  final String? calendarSourceId;
}

class _QuickSaveSheetBody extends ConsumerStatefulWidget {
  const _QuickSaveSheetBody({
    required this.destName,
    required this.anchorMode,
    required this.at,
    required this.route,
    this.initialLabel,
  });

  final String destName;
  final EventAnchor anchorMode;
  final DateTime at;
  final RouteOption route;
  final String? initialLabel;

  @override
  ConsumerState<_QuickSaveSheetBody> createState() =>
      _QuickSaveSheetBodyState();
}

class _QuickSaveSheetBodyState extends ConsumerState<_QuickSaveSheetBody> {
  String? _calendarSourceId;

  late final _labelController = TextEditingController(
    text: widget.initialLabel ?? "",
  );

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  String _rankLabel(RouteType type) {
    switch (type) {
      case RouteType.fastest:
        return "가장 빠른 경로";
      case RouteType.leastWalk:
        return "도보가 적은 경로";
      case RouteType.leastTransfer:
        return "환승이 적은 경로";
    }
  }

  String get _timeSummary {
    final anchorLabel = widget.anchorMode == EventAnchor.arriveBy ? "도착" : "출발";
    final m = widget.at.month;
    final d = widget.at.day;
    final hh = widget.at.hour.toString().padLeft(2, "0");
    final mm = widget.at.minute.toString().padLeft(2, "0");
    return "$m/$d $hh:$mm $anchorLabel";
  }

  /// §3 S-45 "캘린더 선택 — 상태만 변경". 고를 게 둘 이상일 때만 보여준다.
  Widget _buildCalendarPicker() {
    final connections = ref.watch(calendarConnectionsProvider).asData?.value;
    final sources = connections?.writableSources ?? const [];
    if (sources.length < 2) return const SizedBox.shrink();
    final defaultId = connections?.defaultWritableSource?.calendarSourceId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Text(
          "저장할 캘린더",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: EnsomColors.inkMuted,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final source in sources)
              EnsomChip(
                label: source.displayName,
                selected:
                    (_calendarSourceId ?? defaultId) == source.calendarSourceId,
                onTap: () =>
                    setState(() => _calendarSourceId = source.calendarSourceId),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _labelController.text.trim();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: EnsomColors.surfaceNeutral,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "일정으로 저장",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -.2,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: EnsomColors.surface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryRow(icon: Icons.place_outlined, text: widget.destName),
                const SizedBox(height: 8),
                _SummaryRow(icon: Icons.schedule, text: _timeSummary),
                const SizedBox(height: 8),
                _SummaryRow(
                  icon: Icons.alt_route,
                  text:
                      "${_rankLabel(widget.route.routeType)} · ${widget.route.totalMinutes}분",
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          EnsomTextField(
            label: "일정 이름",
            controller: _labelController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
          _buildCalendarPicker(),
          const SizedBox(height: 18),
          EnsomPillButton(
            // §8 S-45 저장은 일정 이름이 있어야만 활성화된다.
            label: "저장",
            onPressed: label.isEmpty
                ? null
                : () => Navigator.pop(
                    context,
                    QuickSaveResult.save(
                      label,
                      calendarSourceId: _calendarSourceId,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          EnsomPillButton(
            label: "더 고칠 게 있으면 자세히 편집",
            variant: EnsomPillVariant.text,
            onPressed: () => Navigator.pop(
              context,
              QuickSaveResult.detailedEdit(
                label.isEmpty ? null : label,
                calendarSourceId: _calendarSourceId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: EnsomColors.inkFaint),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: EnsomColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
