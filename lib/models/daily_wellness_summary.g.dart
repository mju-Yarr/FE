// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_wellness_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DailyWellnessSummary _$DailyWellnessSummaryFromJson(
  Map<String, dynamic> json,
) => _DailyWellnessSummary(
  summaryId: json['summaryId'] as String,
  summaryDate: json['summaryDate'] as String,
  eventCount: (json['eventCount'] as num).toInt(),
  totalOutdoorMinutes: (json['totalOutdoorMinutes'] as num).toInt(),
  onTimeCount: (json['onTimeCount'] as num?)?.toInt() ?? 0,
  arrivalSampleCount: (json['arrivalSampleCount'] as num?)?.toInt() ?? 0,
  dwlBand: $enumDecode(_$DwlBandEnumMap, json['dwlBand']),
  cardScenario: json['cardScenario'] as String,
  message: json['message'] as String,
  isViewed: json['isViewed'] as bool? ?? false,
  dwlScore: (json['dwlScore'] as num?)?.toInt(),
);

Map<String, dynamic> _$DailyWellnessSummaryToJson(
  _DailyWellnessSummary instance,
) => <String, dynamic>{
  'summaryId': instance.summaryId,
  'summaryDate': instance.summaryDate,
  'eventCount': instance.eventCount,
  'totalOutdoorMinutes': instance.totalOutdoorMinutes,
  'onTimeCount': instance.onTimeCount,
  'arrivalSampleCount': instance.arrivalSampleCount,
  'dwlBand': _$DwlBandEnumMap[instance.dwlBand]!,
  'cardScenario': instance.cardScenario,
  'message': instance.message,
  'isViewed': instance.isViewed,
  'dwlScore': instance.dwlScore,
};

const _$DwlBandEnumMap = {
  DwlBand.low: 'low',
  DwlBand.mid: 'mid',
  DwlBand.high: 'high',
};
