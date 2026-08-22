import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_wellness_summary.freezed.dart';
part 'daily_wellness_summary.g.dart';

/// 낮음/보통/높음 3단계. 숫자(dwl_score) 노출 여부는 PRD §31 미결(TRD D5)
/// — 필드는 준비해두되 현재는 band만 필수로 화면에 사용한다.
enum DwlBand {
  @JsonValue('low')
  low,
  @JsonValue('mid')
  mid,
  @JsonValue('high')
  high,
}

@freezed
abstract class DailyWellnessSummary with _$DailyWellnessSummary {
  const factory DailyWellnessSummary({
    required String summaryId, // POST /summary/daily/{summaryId}/viewed 에 필요
    required String summaryDate, // yyyy-MM-dd
    required int eventCount,
    required int totalOutdoorMinutes,
    // 홈 wrap 카드의 "정시 도착" 칸. arrivalSampleCount가 0이면 도착 결과를
    // 하나도 모르는 것이므로 0회로 표시하지 않고 칸을 감춘다.
    @Default(0) int onTimeCount,
    @Default(0) int arrivalSampleCount,
    required DwlBand dwlBand,
    required String cardScenario, // default|exposure|density|rushed|stable
    required String message, // 서버 템플릿 문구. 클라이언트가 재구성하지 않는다
    @Default(false) bool isViewed,
    int? dwlScore, // 노출 여부 미결 — 있어도 화면에 안 쓸 수 있음
  }) = _DailyWellnessSummary;

  factory DailyWellnessSummary.fromJson(Map<String, dynamic> json) =>
      _$DailyWellnessSummaryFromJson(json);
}
