import "package:flutter/material.dart";
import "../../../models/plan.dart";
import "../../../theme/ensom_colors.dart";

/// PLAN-05 체크리스트.
///
/// sourceType은 "사용자 vs 웰니스"가 아니라 데이터 원천(rule/eventItem/
/// weather)이다 -- 웰니스 제안과 사용자 등록이 병합되면 항상
/// sourceType='rule'로 남는다(API v5.0 §9.3). 그래서 이전 라운드에
/// 있던 "웰니스 아이콘"은 여기서 뺐다 -- 그 구분은 이제 Plan.wellnessActions
/// 라는 별도 배열의 몫이다.
///
/// ensom_detail.html `.chk` 패턴 — 라운드 체크박스(21px, radius 7)가
/// 켜지면 cta로 채워지고, 항목 이름은 취소선+연한 회색으로 바뀐다.
class ChecklistSection extends StatelessWidget {
  const ChecklistSection({
    super.key,
    required this.checklist,
    required this.onToggle,
  });

  final List<ChecklistItem> checklist;
  final void Function(ChecklistItem item, bool completed) onToggle;

  @override
  Widget build(BuildContext context) {
    if (checklist.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            "준비물",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -.2,
              color: EnsomColors.ink,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: EnsomColors.surface1,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: EnsomColors.hairline),
          ),
          child: Column(
            children: [
              for (var i = 0; i < checklist.length; i++)
                _ChecklistRow(
                  item: checklist[i],
                  isLast: i == checklist.length - 1,
                  onToggle: onToggle,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.item,
    required this.isLast,
    required this.onToggle,
  });

  final ChecklistItem item;
  final bool isLast;
  final void Function(ChecklistItem item, bool completed) onToggle;

  static const _sensitiveLabel = "개인 준비";

  @override
  Widget build(BuildContext context) {
    final done = item.completionStatus == ChecklistCompletionStatus.completed;
    return InkWell(
      onTap: () => onToggle(item, !done),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: EnsomColors.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CheckBox(checked: done),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.isSensitive ? _sensitiveLabel : item.itemName,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: done
                                ? EnsomColors.inkFaint
                                : EnsomColors.ink,
                            decoration: done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (item.actionType == PrepActionType.timedRoutine &&
                          item.appliedMinutes > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          "+${item.appliedMinutes}분",
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: EnsomColors.inkFaint,
                          ),
                        ),
                      ],
                      if (item.isSensitive) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.lock_outline,
                          size: 13,
                          color: EnsomColors.inkFaint,
                        ),
                      ],
                    ],
                  ),
                  if (!item.isSensitive && item.reason != null && !done) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.reason!,
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
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 21,
        height: 21,
        decoration: BoxDecoration(
          color: checked ? EnsomColors.cta : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: checked ? EnsomColors.cta : EnsomColors.hairline,
            width: 1.8,
          ),
        ),
        child: checked
            ? const Icon(Icons.check, size: 13, color: Colors.white)
            : null,
      ),
    );
  }
}
