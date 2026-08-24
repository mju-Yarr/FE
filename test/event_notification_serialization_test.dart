import "dart:async";

import "package:ensom/core/local_notification_service.dart";
import "package:ensom/models/plan.dart";
import "package:ensom/providers/local_notification_providers.dart";
import "package:ensom/repository/ensom_repository.dart";
import "package:ensom/repository/providers.dart";
import "package:ensom/screens/detail/event_detail_screen.dart";
import "package:ensom/screens/home/home_screen.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

class _ImmediateDeleteRepo implements EnsomRepository {
  @override
  Future<void> deleteEvent(String eventId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _InterleavingNotificationService implements LocalNotificationService {
  final scheduleStarted = Completer<void>();
  final allowScheduleToFinish = Completer<void>();
  final pendingSlots = <String>{"old-prep", "old-depart"};
  final operations = <String>[];

  @override
  Future<void> schedulePlanNotifications({
    required String eventId,
    required int revisionNo,
    required DateTime prepStartAt,
    required DateTime recommendedDepartAt,
    required String eventDisplayName,
    List<String> sensitiveItemNames = const [],
  }) async {
    operations.add("reschedule-start");
    pendingSlots.clear();
    scheduleStarted.complete();
    await allowScheduleToFinish.future;
    pendingSlots.addAll({"new-prep", "new-depart"});
    operations.add("reschedule-finish");
  }

  @override
  Future<void> cancelPlanNotifications({required String eventId}) async {
    operations.add("delete-cancel");
    pendingSlots.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  test(
    "delete cancellation runs after an in-flight reschedule for the same event",
    () async {
      final notifications = _InterleavingNotificationService();
      final container = ProviderContainer(
        overrides: [
          ensomRepositoryProvider.overrideWithValue(_ImmediateDeleteRepo()),
          localNotificationServiceProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      final plan = Plan(
        planId: "plan-1",
        eventId: "event-1",
        revisionNo: 2,
        calcVersion: "test",
        planStatus: PlanStatus.active,
        eventStatus: EventLifecycleStatus.planned,
        feasible: true,
        prepStartAt: DateTime.utc(2026, 8, 25, 1),
        recommendedDepartAt: DateTime.utc(2026, 8, 25, 2),
        targetArriveAt: DateTime.utc(2026, 8, 25, 3),
        breakdown: const PlanBreakdown(
          estimatedPrepMinutes: 10,
          extraPrepMinutes: 0,
          personalRoutineMinutes: 0,
          travelMinutes: 20,
          trafficBufferMinutes: 0,
          arrivalBufferMinutes: 5,
        ),
        reasons: const [],
        checklist: const [],
      );
      final reschedule = scheduleHomePlanNotifications(
        coordinator: container.read(eventNotificationCoordinatorProvider),
        plan: plan,
        eventDisplayName: "meeting",
      );
      await notifications.scheduleStarted.future;

      final deletion = container
          .read(eventDeletionControllerProvider("event-1").notifier)
          .delete();
      await Future<void>.delayed(Duration.zero);

      expect(notifications.operations, ["reschedule-start"]);

      notifications.allowScheduleToFinish.complete();
      await Future.wait([reschedule, deletion]);

      expect(notifications.operations, [
        "reschedule-start",
        "reschedule-finish",
        "delete-cancel",
      ]);
      expect(notifications.pendingSlots, isEmpty);
    },
  );
}
