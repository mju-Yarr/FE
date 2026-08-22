import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../../../models/today_plan.dart";
import "../../../theme/ensom_colors.dart";

/// S-06 히어로 뒤에 겹쳐 보이는 오늘의 남은 일정들.
///
/// §3 S-06 — "뒤에 겹친 카드 탭 → [푸시] S-12 (그 일정)". 겹칠 카드가 없으면
/// 호출부가 이 위젯 자체를 안 그린다(히어로가 폭을 가득 쓴다).
class StackedEventCards extends StatelessWidget {
  const StackedEventCards({
    super.key,
    required this.cards,
    required this.totalCount,
    required this.onTapCard,
    required this.onSeeAll,
  });

  final List<TodayPlanCard> cards;

  /// 히어로 포함 오늘 전체 일정 수. "오늘 일정 N개 모두 보기"에 쓴다.
  final int totalCount;

  final void Function(TodayPlanCard card) onTapCard;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final card in cards) ...[
          EventRowCard(card: card, onTap: () => onTapCard(card)),
          const SizedBox(height: 8),
        ],
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            foregroundColor: EnsomColors.inkMuted,
          ),
          child: Text(
            "오늘 일정 $totalCount개 모두 보기 →",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// 시각·이름·장소·상태 배지 한 줄. 겹친 카드와, 이동 계획이 없어 히어로를
/// 그릴 수 없는 일정에 같이 쓴다.
class EventRowCard extends StatelessWidget {
  const EventRowCard({super.key, required this.card, required this.onTap});

  final TodayPlanCard card;
  final VoidCallback onTap;

  static final _timeFmt = DateFormat("HH:mm");

  @override
  Widget build(BuildContext context) {
    final place = card.event.destinationName;
    final time = _timeFmt.format(card.event.startsAt.toLocal());
    return Material(
      color: EnsomColors.surface1,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: EnsomColors.hairline),
          ),
          child: Row(
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.2,
                  color: EnsomColors.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.event.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: EnsomColors.ink,
                      ),
                    ),
                    // 장소가 없는 일정(온라인 등)에 빈 줄을 만들지 않는다.
                    if (place != null && place.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: EnsomColors.inkFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StateBadge(state: card.state),
            ],
          ),
        ),
      ),
    );
  }
}

/// §9.2 — 상태를 색으로만 구분하지 않는다. 배지 텍스트를 항상 함께 둔다.
class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});

  final HomeCardState state;

  @override
  Widget build(BuildContext context) {
    final caution = state.isCaution;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: caution ? EnsomColors.caution : EnsomColors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        state.badge,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: caution ? EnsomColors.ink : EnsomColors.inkMuted,
        ),
      ),
    );
  }
}
