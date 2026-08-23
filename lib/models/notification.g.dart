// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    _AppNotification(
      notificationId: json['notificationId'] as String,
      planId: json['planId'] as String,
      notificationCategory: $enumDecode(
        _$NotificationCategoryEnumMap,
        json['notificationCategory'],
      ),
      notificationType: $enumDecode(
        _$NotificationTypeEnumMap,
        json['notificationType'],
      ),
      slot: json['slot'] as String,
      scheduledAt: json['scheduledAt'] == null
          ? null
          : DateTime.parse(json['scheduledAt'] as String),
      sentAt: json['sentAt'] == null
          ? null
          : DateTime.parse(json['sentAt'] as String),
      deliveryStatus: $enumDecodeNullable(
        _$DeliveryStatusEnumMap,
        json['deliveryStatus'],
      ),
      body: json['body'] as String,
      triggerReason: json['triggerReason'] as String?,
      reaction: json['reaction'] as String?,
    );

Map<String, dynamic> _$AppNotificationToJson(_AppNotification instance) =>
    <String, dynamic>{
      'notificationId': instance.notificationId,
      'planId': instance.planId,
      'notificationCategory':
          _$NotificationCategoryEnumMap[instance.notificationCategory]!,
      'notificationType': _$NotificationTypeEnumMap[instance.notificationType]!,
      'slot': instance.slot,
      'scheduledAt': instance.scheduledAt?.toIso8601String(),
      'sentAt': instance.sentAt?.toIso8601String(),
      'deliveryStatus': _$DeliveryStatusEnumMap[instance.deliveryStatus],
      'body': instance.body,
      'triggerReason': instance.triggerReason,
      'reaction': instance.reaction,
    };

const _$NotificationCategoryEnumMap = {
  NotificationCategory.time: 'time',
  NotificationCategory.wellness: 'wellness',
};

const _$NotificationTypeEnumMap = {
  NotificationType.relaxed: 'relaxed',
  NotificationType.critical: 'critical',
  NotificationType.disruption: 'disruption',
  NotificationType.wellnessEvent: 'wellness_event',
};

const _$DeliveryStatusEnumMap = {
  DeliveryStatus.delivered: 'delivered',
  DeliveryStatus.pending: 'pending',
  DeliveryStatus.failed: 'failed',
};
