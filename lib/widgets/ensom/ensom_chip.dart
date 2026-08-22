import "package:flutter/material.dart";
import "../../theme/ensom_colors.dart";

/// 목업 `.chip` — 미선택 surface2, 선택 cta 배경(radius 12, 12px/600).
/// `dashed`를 켜면 "+ 직접 추가" 같은 점선 테두리 칩이 된다.
class EnsomChip extends StatelessWidget {
  const EnsomChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dashed = false,
  });

  final String label;
  final bool selected;
  final bool dashed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? EnsomColors.cta : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? null : EnsomColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: dashed
                ? Border.all(color: EnsomColors.hairline, width: 1.4)
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : EnsomColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
