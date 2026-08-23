// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'action_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ActionLogEntry _$ActionLogEntryFromJson(Map<String, dynamic> json) =>
    _ActionLogEntry(
      clientEventId: json['clientEventId'] as String,
      actionType: $enumDecode(_$ActionTypeEnumMap, json['actionType']),
      deviceTs: DateTime.parse(json['deviceTs'] as String),
      actionSource: $enumDecode(_$ActionSourceEnumMap, json['actionSource']),
      confidence: (json['confidence'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$ActionLogEntryToJson(_ActionLogEntry instance) =>
    <String, dynamic>{
      'clientEventId': instance.clientEventId,
      'actionType': _$ActionTypeEnumMap[instance.actionType]!,
      'deviceTs': iso8601WithOffset(instance.deviceTs),
      'actionSource': _$ActionSourceEnumMap[instance.actionSource]!,
      'confidence': instance.confidence,
    };

const _$ActionTypeEnumMap = {
  ActionType.prepStarted: 'prep_started',
  ActionType.prepFinished: 'prep_finished',
  ActionType.snoozed: 'snoozed',
  ActionType.departed: 'departed',
  ActionType.itemChecked: 'item_checked',
  ActionType.excluded: 'excluded',
};

const _$ActionSourceEnumMap = {
  ActionSource.user: 'user',
  ActionSource.geo: 'geo',
  ActionSource.system: 'system',
};

_ActionBatchResponse _$ActionBatchResponseFromJson(Map<String, dynamic> json) =>
    _ActionBatchResponse(
      accepted: (json['accepted'] as num).toInt(),
      duplicated: (json['duplicated'] as num).toInt(),
      eventStatus: $enumDecode(
        _$EventLifecycleStatusEnumMap,
        json['eventStatus'],
      ),
      plan: json['plan'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$ActionBatchResponseToJson(
  _ActionBatchResponse instance,
) => <String, dynamic>{
  'accepted': instance.accepted,
  'duplicated': instance.duplicated,
  'eventStatus': _$EventLifecycleStatusEnumMap[instance.eventStatus]!,
  'plan': instance.plan,
};

const _$EventLifecycleStatusEnumMap = {
  EventLifecycleStatus.planned: 'planned',
  EventLifecycleStatus.notified: 'notified',
  EventLifecycleStatus.preparing: 'preparing',
  EventLifecycleStatus.enroute: 'enroute',
  EventLifecycleStatus.arrived: 'arrived',
  EventLifecycleStatus.closed: 'closed',
  EventLifecycleStatus.skipped: 'skipped',
  EventLifecycleStatus.cancelled: 'cancelled',
  EventLifecycleStatus.unresolved: 'unresolved',
};
