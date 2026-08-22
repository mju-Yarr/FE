class WeeklySummary {
  const WeeklySummary({
    required this.weekStart,
    required this.weekEnd,
    required this.managedEventCount,
    required this.onTimeRate,
    required this.onTimeSampleCount,
    required this.averageSlackMinutes,
    required this.averageSlackSampleCount,
    required this.prepAccuracy,
    required this.wellnessCompletionRate,
    required this.wellnessProposedCount,
    required this.wellnessCompletedCount,
    required this.outdoorMinutes,
    required this.outdoorSampleCount,
    required this.outdoorSource,
  });

  factory WeeklySummary.fromJson(Map<String, dynamic> json) {
    return WeeklySummary(
      weekStart: DateTime.parse(json["weekStart"] as String),
      weekEnd: DateTime.parse(json["weekEnd"] as String),
      managedEventCount: _int(json["managedEventCount"]),
      onTimeRate: _doubleOrNull(json["onTimeRate"]),
      onTimeSampleCount: _int(json["onTimeSampleCount"]),
      averageSlackMinutes: _intOrNull(json["averageSlackMinutes"]),
      averageSlackSampleCount: _int(json["averageSlackSampleCount"]),
      prepAccuracy: (json["prepAccuracy"] as List<dynamic>? ?? const [])
          .map(
            (item) => PrepAccuracyPoint.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      wellnessCompletionRate: _doubleOrNull(json["wellnessCompletionRate"]),
      wellnessProposedCount: _int(json["wellnessProposedCount"]),
      wellnessCompletedCount: _int(json["wellnessCompletedCount"]),
      outdoorMinutes: _int(json["outdoorMinutes"]),
      outdoorSampleCount: _int(json["outdoorSampleCount"]),
      outdoorSource: json["outdoorSource"] as String? ?? "estimated",
    );
  }

  final DateTime weekStart;
  final DateTime weekEnd;
  final int managedEventCount;
  final double? onTimeRate;
  final int onTimeSampleCount;
  final int? averageSlackMinutes;
  final int averageSlackSampleCount;
  final List<PrepAccuracyPoint> prepAccuracy;
  final double? wellnessCompletionRate;
  final int wellnessProposedCount;
  final int wellnessCompletedCount;
  final int outdoorMinutes;
  final int outdoorSampleCount;
  final String outdoorSource;
}

class PrepAccuracyPoint {
  const PrepAccuracyPoint({
    required this.date,
    required this.predictedMinutes,
    required this.actualMinutes,
    required this.sampleCount,
  });

  factory PrepAccuracyPoint.fromJson(Map<String, dynamic> json) {
    return PrepAccuracyPoint(
      date: DateTime.parse(json["date"] as String),
      predictedMinutes: _int(json["predictedMinutes"]),
      actualMinutes: _int(json["actualMinutes"]),
      sampleCount: _int(json["sampleCount"]),
    );
  }

  final DateTime date;
  final int predictedMinutes;
  final int actualMinutes;
  final int sampleCount;
}

int _int(Object? value) => (value as num?)?.toInt() ?? 0;
int? _intOrNull(Object? value) => (value as num?)?.toInt();
double? _doubleOrNull(Object? value) => (value as num?)?.toDouble();
