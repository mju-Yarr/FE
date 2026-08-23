import "package:flutter/material.dart";
import "../../../models/plan.dart";
import "../../../theme/ensom_colors.dart";

/// ensom_prototype.html 홈 화면의 "준비 항목" `.chips` — 상세 화면
/// (ChecklistSection, ensom_detail.html `.chk`)과 달리 홈은 카드가 아니라
/// 가벼운 칩 목록으로 보여준다.
class HomePrepChips extends StatelessWidget {
  const HomePrepChips({super.key, required this.checklist, required this.onToggle});

  final List<ChecklistItem> checklist;
  final void Function(ChecklistItem item, bool completed) onToggle;

  static const _sensitiveLabel = "개인 준비";

  @override
  Widget build(BuildContext context) {
    if (checklist.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            "준비 항목",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: EnsomColors.inkFaint,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in checklist)
              _PrepChip(item: item, onToggle: onToggle),
          ],
        ),
      ],
    );
  }
}

class _PrepChip extends StatelessWidget {
  const _PrepChip({required this.item, required this.onToggle});

  final ChecklistItem item;
  final void Function(ChecklistItem item, bool completed) onToggle;

  @override
  Widget build(BuildContext context) {
    final done = item.completionStatus == ChecklistCompletionStatus.completed;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onToggle(item, !done),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: done ? EnsomColors.surfaceNeutral : EnsomColors.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniCheck(checked: done),
            const SizedBox(width: 7),
            Text(
              item.isSensitive ? HomePrepChips._sensitiveLabel : item.itemName,
              style: TextStyle(
                fontSize: 12.5,
                color: done ? EnsomColors.inkFaint : EnsomColors.ink,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCheck extends StatelessWidget {
  const _MiniCheck({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: checked ? EnsomColors.inkMuted : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: checked ? EnsomColors.inkMuted : EnsomColors.inkFaint,
          width: 1.3,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 9, color: Colors.white)
          : null,
    );
  }
}
