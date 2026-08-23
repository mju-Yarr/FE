import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../../theme/ensom_colors.dart";

/// 홈 화면에 다가오는 일정이 없을 때 표시되는 빈 상태 위젯.
/// ensom_empty_error.html의 홈-없음 카드.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      decoration: BoxDecoration(
        color: EnsomColors.surface1,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: EnsomColors.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "관리할 다음 일정이 없어요",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "일정을 추가하면 준비 시작 시각을 알려드릴게요",
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: EnsomColors.inkMuted,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push("/calendar/new"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnsomColors.cta,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    "일정 만들기",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.go("/map"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EnsomColors.surface2,
                    foregroundColor: EnsomColors.ink,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    "지도에서 찾기",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
