import 'package:freezed_annotation/freezed_annotation.dart';

part 'prep_estimate.freezed.dart';
part 'prep_estimate.g.dart';

/// 설정 화면의 "처음 입력한 준비 시간 30분 / 최근 학습된 저녁 약속 준비 시간
/// 42분" 이중 표기를 위한 모델. initialPrepMinutes(자기보고 시드)는
/// UserSettings에, 이 모델은 학습된 값에만 대응한다.
@freezed
abstract class PrepEstimate with _$PrepEstimate {
  const factory PrepEstimate({
    required String
    scopeType, // global | event_kind | weather | origin_place | time_band
    String? scopeValue,
    required int estimatedMinutes,
    required int sampleCount,
    // BE 응답 필드명은 adjustmentReason(API v5.0 §15 · ERD USER_PREP_ESTIMATE).
    // JsonKey 없이는 json['lastReason']을 찾아 항상 null이 되어 보정 근거가
    // 화면에 뜨지 않는다.
    @JsonKey(name: "adjustmentReason")
    String? lastReason, // 계산 근거 표시용 (PLAN-03)
  }) = _PrepEstimate;

  factory PrepEstimate.fromJson(Map<String, dynamic> json) =>
      _$PrepEstimateFromJson(json);
}
