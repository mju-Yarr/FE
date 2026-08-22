// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Event _$EventFromJson(Map<String, dynamic> json) => _Event(
  eventId: json['eventId'] as String,
  title: json['title'] as String?,
  displayLabel: json['displayLabel'] as String?,
  displayName: json['displayName'] as String,
  startsAt: DateTime.parse(json['startsAt'] as String),
  endsAt: json['endsAt'] == null
      ? null
      : DateTime.parse(json['endsAt'] as String),
  locationState: $enumDecode(_$LocationStateEnumMap, json['locationState']),
  destinationName: json['destinationName'] as String?,
  destinationLat: (json['destinationLat'] as num?)?.toDouble(),
  destinationLng: (json['destinationLng'] as num?)?.toDouble(),
  anchor:
      $enumDecodeNullable(_$EventAnchorEnumMap, json['anchor']) ??
      EventAnchor.arriveBy,
  sourceType:
      $enumDecodeNullable(_$EventSourceTypeEnumMap, json['sourceType']) ??
      EventSourceType.internal,
  status: $enumDecodeNullable(_$EventLifecycleStatusEnumMap, json['status']),
  autoManageExcluded: json['autoManageExcluded'] as bool?,
);

Map<String, dynamic> _$EventToJson(_Event instance) => <String, dynamic>{
  'eventId': instance.eventId,
  'title': instance.title,
  'displayLabel': instance.displayLabel,
  'displayName': instance.displayName,
  'startsAt': instance.startsAt.toIso8601String(),
  'endsAt': instance.endsAt?.toIso8601String(),
  'locationState': _$LocationStateEnumMap[instance.locationState]!,
  'destinationName': instance.destinationName,
  'destinationLat': instance.destinationLat,
  'destinationLng': instance.destinationLng,
  'anchor': _$EventAnchorEnumMap[instance.anchor]!,
  'sourceType': _$EventSourceTypeEnumMap[instance.sourceType]!,
  'status': _$EventLifecycleStatusEnumMap[instance.status],
  'autoManageExcluded': instance.autoManageExcluded,
};

const _$LocationStateEnumMap = {
  LocationState.requiredResolved: 'required_resolved',
  LocationState.requiredMissing: 'required_missing',
  LocationState.notRequired: 'not_required',
  LocationState.undecided: 'undecided',
};

const _$EventAnchorEnumMap = {
  EventAnchor.arriveBy: 'arrive_by',
  EventAnchor.departAt: 'depart_at',
};

const _$EventSourceTypeEnumMap = {
  EventSourceType.internal: 'internal',
  EventSourceType.external: 'external',
  EventSourceType.mapSearch: 'map_search',
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

_EventClassificationReview _$EventClassificationReviewFromJson(
  Map<String, dynamic> json,
) => _EventClassificationReview(
  questionType: json['questionType'] as String,
  userAnswer: json['userAnswer'] as String,
);

Map<String, dynamic> _$EventClassificationReviewToJson(
  _EventClassificationReview instance,
) => <String, dynamic>{
  'questionType': instance.questionType,
  'userAnswer': instance.userAnswer,
};
