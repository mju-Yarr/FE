import "package:ensom/core/local_notification_service.dart";
import "package:ensom/models/weekly_summary.dart";
import "package:ensom/providers/calendar_providers.dart";
import "package:ensom/repository/ensom_repository.dart";
import "package:ensom/repository/providers.dart";
import "package:ensom/screens/detail/event_detail_screen.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

/// P3 회귀: 이전 테스트는 ref.invalidate(weeklySummaryProvider) 호출을
/// 스파이하지 않아서, 그 줄을 지워도 통과했다. 이 테스트는 실제로
/// 살아있는(active) weeklySummaryProvider 인스턴스가 삭제 성공 후
/// 다시 fetch되는지 — 즉 진짜 무효화가 일어나는지를 직접 관찰한다.
class _FakeRepo implements EnsomRepository {
  int deleteCalls = 0;
  int weeklySummaryFetchCalls = 0;

  @override
  Future<void> deleteEvent(String eventId) async {
    deleteCalls++;
  }

  @override
  Future<WeeklySummary> fetchWeeklySummary(String date) async {
    weeklySummaryFetchCalls++;
    return WeeklySummary(
      weekStart: DateTime(2026, 8, 17),
      weekEnd: DateTime(2026, 8, 23),
      managedEventCount: 0,
      onTimeRate: null,
      onTimeSampleCount: 0,
      averageSlackMinutes: null,
      averageSlackSampleCount: 0,
      prepAccuracy: [],
      wellnessCompletionRate: null,
      wellnessProposedCount: 0,
      wellnessCompletedCount: 0,
      outdoorMinutes: 0,
      outdoorSampleCount: 0,
      outdoorSource: "estimated",
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NoopNotificationService implements LocalNotificationService {
  @override
  Future<void> cancelPlanNotifications({required String eventId}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  test("삭제 성공 시 활성 weeklySummaryProvider 인스턴스가 다시 fetch된다", () async {
    final repo = _FakeRepo();
    final container = ProviderContainer(
      overrides: [
        ensomRepositoryProvider.overrideWithValue(repo),
        localNotificationServiceProvider.overrideWithValue(
          _NoopNotificationService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final date = DateTime(2026, 8, 24);
    // weeklySummaryProvider는 autoDispose라 listen으로 구독을 유지해야
    // "활성" 상태가 되고, 삭제 후 invalidate가 실제 refetch로 이어지는지
    // 관찰할 수 있다.
    container.listen(weeklySummaryProvider(date), (_, _) {});
    await container.read(weeklySummaryProvider(date).future);
    expect(repo.weeklySummaryFetchCalls, 1);

    await container
        .read(eventDeletionControllerProvider("event-1").notifier)
        .delete();

    expect(repo.deleteCalls, 1);
    await container.read(weeklySummaryProvider(date).future);
    expect(
      repo.weeklySummaryFetchCalls,
      2,
      reason: "weeklySummaryProvider가 삭제 후 invalidate돼 다시 fetch돼야 한다",
    );
  });
}
