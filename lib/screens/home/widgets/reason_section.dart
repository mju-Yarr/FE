import "package:flutter/material.dart";
import "../../../models/plan.dart";
import "../../../theme/ensom_colors.dart";

/// PLAN-03. API v5.0 §9.1 reasons 배열. 분 단위 값은 여기 없다(원본은
/// breakdown에 있고, 이건 그 값의 근거 문장만 담는다) -- 지난 라운드의
/// PlanReason(label/minutes) 구조를 field/source/adjusted/text로 교체.
///
/// ensom_detail.html "계산 근거" 섹션의 기본 접힘 + "자세히" 토글
/// 패턴을 반영한다(PRD "근거를 항상 제공하되 전면에 내세우지 않는다").
class ReasonSection extends StatefulWidget {
  const ReasonSection({super.key, required this.reasons});

  final List<PlanReason> reasons;

  @override
  State<ReasonSection> createState() => _ReasonSectionState();
}

class _ReasonSectionState extends State<ReasonSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.reasons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Text(
                  "계산 근거",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.2,
                    color: EnsomColors.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  _expanded ? "접기" : "자세히",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: EnsomColors.inkFaint,
                  ),
                ),
                const SizedBox(width: 3),
                AnimatedRotation(
                  turns: _expanded ? .5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 15,
                    color: EnsomColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: EnsomColors.surface1,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: EnsomColors.hairline),
            ),
            child: Column(
              children: [
                for (var i = 0; i < widget.reasons.length; i++)
                  _ReasonRow(
                    item: widget.reasons[i],
                    isLast: i == widget.reasons.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.item, required this.isLast});

  final PlanReason item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: EnsomColors.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.adjusted ? Icons.trending_up : Icons.circle_outlined,
            size: 13,
            color: item.adjusted ? EnsomColors.caution : EnsomColors.inkFaint,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.text,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: item.adjusted
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: EnsomColors.ink,
                  ),
                ),
                if (item.sampleCount != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    "최근 ${item.sampleCount}회 기록 기준",
                    style: const TextStyle(
                      fontSize: 11,
                      color: EnsomColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
