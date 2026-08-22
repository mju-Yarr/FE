import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../../theme/ensom_colors.dart";

/// 홈 화면에 다가오는 일정이 없을 때 표시되는 빈 상태 위젯.
/// "일정 만들기"(primary)와 "캘린더 연동하기"(secondary) 2개의 CTA를 제공한다.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_available,
            size: 48,
            color: EnsomColors.inkMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            "다가오는 일정이 없어요.",
            style: TextStyle(color: EnsomColors.inkMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push("/calendar/new"),
            style: ElevatedButton.styleFrom(
              backgroundColor: EnsomColors.cta,
              foregroundColor: EnsomColors.canvas,
              minimumSize: const Size(200, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("일정 만들기"),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push("/calendar/connections"),
            style: OutlinedButton.styleFrom(
              foregroundColor: EnsomColors.ink,
              side: const BorderSide(color: EnsomColors.hairline),
              minimumSize: const Size(200, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("캘린더 연동하기"),
          ),
        ],
      ),
    );
  }
}
