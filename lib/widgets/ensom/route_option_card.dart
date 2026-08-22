import "package:flutter/material.dart";
import "../../models/plan.dart";
import "../../theme/ensom_colors.dart";

/// MAP-02/RTE-01 경로 카드 — 경로 선택 화면(S-11)과 경로 변경 시트가
/// 공유한다. 랭크(가장 빠른/도보 적은/환승 적은)별 아이콘 + 총 시간 +
/// 도보·환승 요약, 선택 상태는 테두리 강조 + 체크로 표시한다.
class EnsomRouteOptionCard extends StatelessWidget {
  const EnsomRouteOptionCard({
    super.key,
    required this.option,
    required this.selected,
    this.onSelect,
  });

  final RouteOption option;
  final bool selected;
  final VoidCallback? onSelect;

  static String _label(RouteType type) {
    switch (type) {
      case RouteType.fastest:
        return "가장 빠른 경로";
      case RouteType.leastWalk:
        return "도보가 적은 경로";
      case RouteType.leastTransfer:
        return "환승이 적은 경로";
    }
  }

  static IconData _icon(RouteType type) {
    switch (type) {
      case RouteType.fastest:
        return Icons.bolt;
      case RouteType.leastWalk:
        return Icons.directions_walk;
      case RouteType.leastTransfer:
        return Icons.swap_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EnsomColors.surface1,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: selected ? EnsomColors.cta : EnsomColors.hairline,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: EnsomColors.surface2,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon(option.routeType),
                  size: 17,
                  color: EnsomColors.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label(option.routeType),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: EnsomColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "${option.totalMinutes}분",
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.4,
                        color: EnsomColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "도보 ${option.walkMinutes}분 · 환승 ${option.transferCount}회",
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: EnsomColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                const Icon(Icons.check_circle, size: 22, color: EnsomColors.cta)
              else
                Material(
                  color: EnsomColors.cta,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: onSelect,
                    borderRadius: BorderRadius.circular(999),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        "선택",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
