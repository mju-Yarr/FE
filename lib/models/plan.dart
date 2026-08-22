import "package:freezed_annotation/freezed_annotation.dart";

part "plan.freezed.dart";
part "plan.g.dart";

/// 계획 리비전 상태(ERD plan_revision.plan_status). eventStatus와
/// 완전히 다른 축이다 -- API v5.0 §9.2 "planStatus ≠ eventStatus".
/// 실제 서버가 사용하는 값: active / superseded (2개).
enum PlanStatus {
  @JsonValue("active")
  active,
  @JsonValue("superseded")
  superseded,
}

/// 일정 생명주기(ERD event.status). BE ck_event_status 제약 9개 값 전부.
enum EventLifecycleStatus {
  @JsonValue("planned")
  planned,
  @JsonValue("notified")
  notified,
  @JsonValue("preparing")
  preparing,
  @JsonValue("enroute")
  enroute,
  @JsonValue("arrived")
  arrived,
  @JsonValue("closed")
  closed,
  @JsonValue("skipped")
  skipped,
  @JsonValue("cancelled")
  cancelled,
  @JsonValue("unresolved")
  unresolved,
}

/// breakdown의 한 필드가 왜 그 값인지 설명하는 근거 한 줄.
/// 분 단위 값 자체는 여기 없다 -- 실제 값은 PlanBreakdown에 있고,
/// 이건 그 값의 "이유"만 담는다 (API v5.0 §9.1).
@freezed
abstract class PlanReason with _$PlanReason {
  const factory PlanReason({
    required String field, // breakdown 필드명 (estimatedPrepMinutes 등)
    required String source, // estimate | prepRule | routeProvider | environment
    required bool adjusted,
    required String text,
    int? sampleCount,
  }) = _PlanReason;

  factory PlanReason.fromJson(Map<String, dynamic> json) =>
      _$PlanReasonFromJson(json);
}

@freezed
abstract class PlanBreakdown with _$PlanBreakdown {
  const factory PlanBreakdown({
    required int estimatedPrepMinutes,
    required int extraPrepMinutes,
    required int personalRoutineMinutes,
    required int travelMinutes,
    required int trafficBufferMinutes,
    required int arrivalBufferMinutes,
  }) = _PlanBreakdown;

  factory PlanBreakdown.fromJson(Map<String, dynamic> json) =>
      _$PlanBreakdownFromJson(json);
}

/// ERD PLAN_PREP_ITEM.source_type 값 (사용자/웰니스 구분이 아니라
/// 데이터 원천 구분이다 -- rule=사용자 등록 규칙에서 투영, 그 외는 P1).
enum ChecklistSourceType {
  @JsonValue("rule")
  rule,
  @JsonValue("event_item")
  eventItem,
  @JsonValue("weather")
  weather,
}

enum ChecklistCompletionStatus {
  @JsonValue("pending")
  pending,
  @JsonValue("completed")
  completed,
}

enum PrepActionType {
  @JsonValue("carry")
  carry,
  @JsonValue("consume")
  consume,
  @JsonValue("purchase")
  purchase,
  @JsonValue("timed_routine")
  timedRoutine,
}

@freezed
abstract class ChecklistItem with _$ChecklistItem {
  const factory ChecklistItem({
    required String planPrepItemId,
    required String itemName,
    required PrepActionType actionType,
    required ChecklistSourceType sourceType,
    required ChecklistCompletionStatus completionStatus,
    @Default(false) bool isSensitive,
    @Default(0) int appliedMinutes,
    String? reason,
  }) = _ChecklistItem;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemFromJson(json);
}

/// checklist와 완전히 별도 배열이다 (API v5.0 §9.2 "checklist와
/// wellnessActions는 별도 배열"). M1에서는 파싱만 하고 UI 상호작용은
/// M3(feat/fe-wellness) 범위로 남긴다.
enum WellnessActionCompletionStatus {
  @JsonValue("proposed")
  proposed,
  @JsonValue("completed")
  completed,
  @JsonValue("dismissed")
  dismissed,
}

@freezed
abstract class WellnessAction with _$WellnessAction {
  const factory WellnessAction({
    required String wellnessActionId,
    required String wellnessTopic,
    required String actionCode,
    required String actionLabel,
    required int displayRank,
    String? reasonSnapshot,
    required WellnessActionCompletionStatus completionStatus,
  }) = _WellnessAction;

  factory WellnessAction.fromJson(Map<String, dynamic> json) =>
      _$WellnessActionFromJson(json);
}

enum WisBand {
  @JsonValue("low")
  low,
  @JsonValue("mid")
  mid,
  @JsonValue("high")
  high,
}

@freezed
abstract class WellnessSummary with _$WellnessSummary {
  const factory WellnessSummary({
    required int wisScore,
    required WisBand wisBand,
    required String weightVersion,
    required bool eventArmed,
  }) = _WellnessSummary;

  factory WellnessSummary.fromJson(Map<String, dynamic> json) =>
      _$WellnessSummaryFromJson(json);
}

@freezed
abstract class PlanContext with _$PlanContext {
  const factory PlanContext({
    int? uvIndex,
    int? pm10,
    int? pm25,
    double? feelsLike,
    int? precipitationProb,
    required int estimatedOutdoorMinutes,
    String? weatherProvider,
    String? airProvider,
    DateTime? observedAt,
  }) = _PlanContext;

  factory PlanContext.fromJson(Map<String, dynamic> json) =>
      _$PlanContextFromJson(json);
}

/// GET /plans/{planId} 응답 (API v5.0 §9.1) 그대로.
@freezed
abstract class Plan with _$Plan {
  const factory Plan({
    required String planId,
    required String eventId,
    required int revisionNo,
    required String calcVersion,
    required PlanStatus planStatus,
    required EventLifecycleStatus eventStatus,
    required bool feasible,
    String? predictionConfidence,
    required DateTime prepStartAt,
    required DateTime recommendedDepartAt,
    required DateTime targetArriveAt,
    required PlanBreakdown breakdown,
    required List<PlanReason> reasons,
    required List<ChecklistItem> checklist,
    @Default([]) List<WellnessAction> wellnessActions,
    WellnessSummary? wellness,
    PlanContext? context,
    String? selectedRouteOptionId,
    @Default([]) List<String> degraded,
  }) = _Plan;

  factory Plan.fromJson(Map<String, dynamic> json) => _$PlanFromJson(json);
}

enum RouteType {
  @JsonValue("fastest")
  fastest,
  @JsonValue("least_walk")
  leastWalk,
  @JsonValue("least_transfer")
  leastTransfer,
}

/// API v5.0 §10.1. 단위는 분(minutes)이다 -- 이전 버전의 초 단위 표기는
/// 폐기됐다.
@freezed
abstract class RouteOption with _$RouteOption {
  const factory RouteOption({
    required String routeOptionId,
    required int routeRank,
    required RouteType routeType,
    required int totalMinutes,
    required int walkMinutes,
    required int transferCount,
    DateTime? departAt,
    DateTime? arriveAt,
  }) = _RouteOption;

  factory RouteOption.fromJson(Map<String, dynamic> json) =>
      _$RouteOptionFromJson(json);
}
