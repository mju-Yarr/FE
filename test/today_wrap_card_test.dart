import "package:ensom/models/daily_wellness_summary.dart";
import "package:ensom/screens/home/widgets/today_wrap_card.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

/// S-06 wrap — "준비 체크리스트·웰니스 섹션 대신 오늘 요약 3칸(관리한 일정 /
/// 정시 도착 / 야외 이동)을 보여준다".
DailyWellnessSummary _summary({
  int eventCount = 3,
  int onTimeCount = 2,
  int arrivalSampleCount = 3,
  int totalOutdoorMinutes = 70,
}) => DailyWellnessSummary(
  summaryId: "s1",
  summaryDate: "2026-08-22",
  eventCount: eventCount,
  totalOutdoorMinutes: totalOutdoorMinutes,
  onTimeCount: onTimeCount,
  arrivalSampleCount: arrivalSampleCount,
  dwlBand: DwlBand.mid,
  cardScenario: "stable",
  message: "오늘은 무리 없이 안정적으로 하루를 보냈어요.",
);

Future<void> _pump(WidgetTester tester, DailyWellnessSummary? summary) async {
  tester.view.physicalSize = const Size(834, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TodayWrapCard(summary: summary, onTap: () {}),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets("요약 3칸을 모두 보여준다", (tester) async {
    await _pump(tester, _summary());

    expect(find.text("3개"), findsOneWidget);
    expect(find.text("관리한 일정"), findsOneWidget);
    expect(find.text("2회"), findsOneWidget);
    expect(find.text("정시 도착"), findsOneWidget);
    expect(find.text("1시간 10분"), findsOneWidget);
    expect(find.text("야외 이동"), findsOneWidget);
  });

  testWidgets("도착 결과를 모르면 정시 도착 칸을 감춘다", (tester) async {
    // 0회를 "정시가 한 번도 없었다"로 읽히게 두지 않는다.
    await _pump(tester, _summary(onTimeCount: 0, arrivalSampleCount: 0));

    expect(find.text("정시 도착"), findsNothing);
    expect(find.text("관리한 일정"), findsOneWidget);
    expect(find.text("야외 이동"), findsOneWidget);
  });

  testWidgets("정시가 실제로 0회면 칸을 보여준다", (tester) async {
    await _pump(tester, _summary(onTimeCount: 0, arrivalSampleCount: 2));

    expect(find.text("정시 도착"), findsOneWidget);
    expect(find.text("0회"), findsOneWidget);
  });

  testWidgets("서버 문구를 그대로 쓴다", (tester) async {
    await _pump(tester, _summary());
    expect(find.text("오늘은 무리 없이 안정적으로 하루를 보냈어요."), findsOneWidget);
  });

  testWidgets("요약이 없으면 숫자 칸 없이 마무리 문구만 보여준다", (tester) async {
    await _pump(tester, null);

    expect(find.text("오늘 일정을 모두 마쳤어요."), findsOneWidget);
    expect(find.text("오늘 요약"), findsNothing);
    expect(find.text("관리한 일정"), findsNothing);
  });

  testWidgets("야외 이동이 한 시간 미만이면 분으로만 적는다", (tester) async {
    await _pump(tester, _summary(totalOutdoorMinutes: 45));
    expect(find.text("45분"), findsOneWidget);
  });
}
