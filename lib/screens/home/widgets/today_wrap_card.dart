import "package:flutter/material.dart";
import "../../../models/daily_wellness_summary.dart";
import "../../../theme/ensom_colors.dart";
import "../../../widgets/ensom/ensom_pill_button.dart";

/// S-06의 wrap 상태 — 일일 마무리. §3 "wrap은 일일 마무리 카드다. 별도 화면을
/// 만들지 않는다"에 따라 히어로 카드를 이 카드로 대체한다.
///
/// 겹친 카드를 두지 않고 폭을 가득 쓰며, 준비 체크리스트·웰니스 섹션 대신
/// 오늘 요약을 보여준다.
class TodayWrapCard extends StatelessWidget {
  const TodayWrapCard({super.key, required this.summary, required this.onTap});

  /// 요약 생성에 실패하면 null이 온다. 그때는 숫자 칸을 지어내지 않고
  /// 마무리 문구만 보여준다.
  final DailyWellnessSummary? summary;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = summary;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        // §9.2 큰 라임 면이 허용되는 세 곳 중 하나가 홈 히어로 카드다.
        color: EnsomColors.lime,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            margin: const EdgeInsets.only(right: 0),
            decoration: BoxDecoration(
              color: EnsomColors.ink.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "오늘 마무리",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: EnsomColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "오늘 일정을 모두 마쳤어요.",
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -.3,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            // 서버 템플릿 문구를 클라이언트가 재구성하지 않는다.
            data?.message ?? "준비와 도착 흐름을 정리했어요. 지금은 편하게 쉬어주세요.",
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: EnsomColors.limeInk,
            ),
          ),
          if (data != null) ...[
            const SizedBox(height: 18),
            const Text(
              "오늘 요약",
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: EnsomColors.limeInk,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _SummaryCell(value: "${data.eventCount}개", label: "관리한 일정"),
                // 도착 결과를 하나도 모르면(표본 0) "0회"가 정시가 없었다는
                // 뜻으로 읽힌다. 그럴 땐 칸을 감춘다.
                if (data.arrivalSampleCount > 0)
                  _SummaryCell(value: "${data.onTimeCount}회", label: "정시 도착"),
                _SummaryCell(
                  value: _formatMinutes(data.totalOutdoorMinutes),
                  label: "야외 이동",
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          EnsomPillButton(label: "오늘 기록 보기", onPressed: onTap),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return "$minutes분";
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? "$hours시간" : "$hours시간 $rest분";
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -.3,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: EnsomColors.limeInk),
          ),
        ],
      ),
    );
  }
}
