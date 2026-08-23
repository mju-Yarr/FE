import "package:flutter_test/flutter_test.dart";
import "package:ensom/models/notification.dart";

void main() {
  group("notification response contract", () {
    test("parses a delivered time notification", () {
      final notification = AppNotification.fromJson({
        "notificationId": "11111111-1111-1111-1111-111111111111",
        "planId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "notificationCategory": "time",
        "notificationType": "relaxed",
        "slot": "A",
        "scheduledAt": "2026-08-20T00:00:00Z",
        "sentAt": "2026-08-20T00:01:00Z",
        "deliveryStatus": "delivered",
        "body": "준비를 시작할 시간이에요.",
        "triggerReason": "prep_start",
        "reaction": "prep_started",
      });

      expect(notification.notificationCategory, NotificationCategory.time);
      expect(notification.planId, "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
      expect(notification.notificationType, NotificationType.relaxed);
      expect(notification.slot, "A");
      expect(notification.deliveryStatus, DeliveryStatus.delivered);
      expect(notification.body, "준비를 시작할 시간이에요.");
      expect(notification.reaction, "prep_started");
    });

    test("parses a pending wellness notification", () {
      final notification = AppNotification.fromJson({
        "notificationId": "22222222-2222-2222-2222-222222222222",
        "planId": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
        "notificationCategory": "wellness",
        "notificationType": "wellness_event",
        "slot": "W",
        "scheduledAt": "2026-08-20T02:00:00Z",
        "sentAt": null,
        "deliveryStatus": "pending",
        "body": "잠깐 쉬어가는 건 어떨까요?",
        "triggerReason": "wellness_rule",
        "reaction": "completed",
      });

      expect(notification.notificationCategory, NotificationCategory.wellness);
      expect(notification.notificationType, NotificationType.wellnessEvent);
      expect(notification.slot, "W");
      expect(notification.deliveryStatus, DeliveryStatus.pending);
      expect(notification.body, "잠깐 쉬어가는 건 어떨까요?");
      expect(notification.reaction, "completed");
    });

    test("parses a failed disruption notification", () {
      final notification = AppNotification.fromJson({
        "notificationId": "33333333-3333-3333-3333-333333333333",
        "planId": "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "notificationCategory": "time",
        "notificationType": "disruption",
        "slot": "C",
        "scheduledAt": "2026-08-20T03:00:00Z",
        "deliveryStatus": "failed",
        "body": "일정 변경을 확인해 주세요.",
      });

      expect(notification.notificationType, NotificationType.disruption);
      expect(notification.slot, "C");
      expect(notification.deliveryStatus, DeliveryStatus.failed);
      expect(notification.reaction, isNull);
    });
  });
}
