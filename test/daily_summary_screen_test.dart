import "package:ensom/models/daily_wellness_summary.dart";
import "package:ensom/repository/ensom_repository.dart";
import "package:ensom/repository/providers.dart";
import "package:ensom/screens/summary/daily_summary_screen.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

/// fetchDailySummary만 관측하는 최소 fake. 나머지 추상 메서드는
/// 테스트에서 호출되지 않으므로 noSuchMethod로 처리한다.
class _FakeRepo implements EnsomRepository {
  int fetchCount = 0;

  @override
  Future<DailyWellnessSummary?> fetchDailySummary(String date) async {
    fetchCount++;
    return const DailyWellnessSummary(
      summaryId: "s1",
      summaryDate: "2026-08-24",
      eventCount: 2,
      totalOutdoorMinutes: 30,
      dwlBand: DwlBand.low,
      cardScenario: "default",
      message: "오늘도 수고했어요.",
      isViewed: true, // markDailySummaryViewed 호출까지는 검증 범위 밖.
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  testWidgets("dailySummaryProvider가 리빌드돼도 fetchDailySummary는 한 번만 호출된다", (
    tester,
  ) async {
    final repo = _FakeRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ensomRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: DailySummaryScreen()),
      ),
    );
    // 1차 pump: loading -> data 전환으로 build()가 다시 호출된다.
    await tester.pump();
    await tester.pump();
    // 2차 pump: data 상태에서 한 번 더 리빌드를 유도한다.
    await tester.pump();

    // DateTime.now()를 그대로 family 키로 쓰면 리빌드마다 밀리초가 달라져
    // provider가 매번 새로 생성되고 fetchDailySummary가 반복 호출된다.
    expect(repo.fetchCount, 1);
  });
}
