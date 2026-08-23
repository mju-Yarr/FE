import "package:freezed_annotation/freezed_annotation.dart";

part "notification.freezed.dart";
part "notification.g.dart";

enum NotificationCategory {
  @JsonValue("time")
  time,
  @JsonValue("wellness")
  wellness,
}

/// notificationCategory와의 정합성은 서버가 CHECK 제약으로 강제한다
/// (ERD ck_noti_category) -- wellness_event는 반드시 wellness 카테고리.
enum NotificationType {
  @JsonValue("relaxed")
  relaxed,
  @JsonValue("critical")
  critical,
  @JsonValue("disruption")
  disruption,
  @JsonValue("wellness_event")
  wellnessEvent,
}

enum DeliveryStatus {
  @JsonValue("delivered")
  delivered,
  @JsonValue("pending")
  pending,
  @JsonValue("failed")
  failed,
}

/// GET /notifications/today 응답 원소 (API v5.0 §11.1) 그대로.
/// body는 서버가 내려주는 최종 문자열 -- 클라이언트가 변형하지 않는다
/// (TR-09). 민감 준비 항목이 관련된 알림은 body 자체가 이미
/// body_masked로 일반화된 문구다.
@freezed
abstract class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String notificationId,
    required String planId,
    required NotificationCategory notificationCategory,
    required NotificationType notificationType,
    required String slot, // time: A|B|C, wellness: W
    DateTime? scheduledAt,
    DateTime? sentAt,
    DeliveryStatus? deliveryStatus,
    required String body,
    String? triggerReason,
    String? reaction,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}

/// POST /notifications/{id}/respond 요청 바디의 BE reaction 값.
/// 서버가 허용한 값만 선언한다. 웰니스 완료/중단 UX는 별도 endpoint 계약이
/// 확정되기 전까지 이 notification response API로 전송하지 않는다.
enum NotificationReaction {
  @JsonValue("started")
  started,
  @JsonValue("snoozed")
  snoozed,
  @JsonValue("dismissed")
  dismissed,
  @JsonValue("departed")
  departed,
}
