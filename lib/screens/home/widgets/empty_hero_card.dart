import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../../theme/ensom_colors.dart";
import "../../../widgets/ensom/ensom_pill_button.dart";

/// ensom_prototype.html `.hero.empty` — 일정이 0건일 때 히어로 카드
/// 자리에 그대로 들어가는 빈 상태다(별도 카드 섹션이 아니라 히어로와
/// 같은 위치·같은 radius를 쓴다). 탭해도 아무 동작이 없다
/// (`cursor:default`) — 버튼 두 개만 각자 반응한다.
class EmptyHeroCard extends StatelessWidget {
  const EmptyHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: EnsomColors.surface1,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: EnsomColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "관리할 다음 일정이 없어요",
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -.8,
              height: 1.2,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "일정을 추가하면 준비 시작 시각을 알려드릴게요.",
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: EnsomColors.inkMuted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: EnsomPillButton(
                  label: "일정 만들기",
                  onPressed: () => context.push("/calendar/new"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: EnsomPillButton(
                  label: "캘린더 연동",
                  variant: EnsomPillVariant.secondary,
                  onPressed: () => context.push("/calendar/connections"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
