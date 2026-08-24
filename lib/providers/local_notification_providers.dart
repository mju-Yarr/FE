import "package:flutter_riverpod/flutter_riverpod.dart";
import "../core/local_notification_service.dart";

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return LocalNotificationService.instance;
});

final eventNotificationCoordinatorProvider =
    Provider<EventNotificationCoordinator>((ref) {
      return EventNotificationCoordinator(
        ref.watch(localNotificationServiceProvider),
      );
    });

/// 같은 일정의 모든 알림 변경을 시작 순서대로 실행한다.
///
/// 재예약은 내부적으로 `기존 알림 취소 → 새 알림 예약`을 수행하므로 일정
/// 삭제의 취소와 겹치면 삭제 후 알림이 뒤늦게 생길 수 있다. 홈과 상세 등
/// 모든 producer가 이 coordinator를 공유해 eventId별 FIFO를 보장한다.
class EventNotificationCoordinator {
  EventNotificationCoordinator(this.notifications);

  final LocalNotificationService notifications;
  final Map<String, Future<void>> _tails = {};

  Future<void> reschedule({
    required String eventId,
    required int revisionNo,
    required DateTime prepStartAt,
    required DateTime recommendedDepartAt,
    required String eventDisplayName,
  }) {
    return _enqueue(
      eventId,
      () => notifications.schedulePlanNotifications(
        eventId: eventId,
        revisionNo: revisionNo,
        prepStartAt: prepStartAt,
        recommendedDepartAt: recommendedDepartAt,
        eventDisplayName: eventDisplayName,
      ),
    );
  }

  Future<void> cancel(String eventId) {
    return _enqueue(
      eventId,
      () => notifications.cancelPlanNotifications(eventId: eventId),
    );
  }

  Future<void> _enqueue(String eventId, Future<void> Function() operation) {
    final previous = _tails[eventId] ?? Future<void>.value();
    late final Future<void> current;
    current = previous
        .catchError((Object error, StackTrace stackTrace) {})
        .then<void>((_) => operation())
        .whenComplete(() {
          if (identical(_tails[eventId], current)) {
            _tails.remove(eventId);
          }
        });
    _tails[eventId] = current;
    return current;
  }
}
