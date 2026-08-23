import "package:freezed_annotation/freezed_annotation.dart";
import "plan.dart"; // EventLifecycleStatus

part "action_log.freezed.dart";
part "action_log.g.dart";

/// API v5.0 §13 "v3.0에서 잘못 포함됐던 것들" 반영:
/// arrived(→execution으로), wellness_done/later/stop(→wellness resolve로),
/// checklist_done(→item_checked로 개명), plan_edited(→PATCH plans로) 제거.
enum ActionType {
  @JsonValue("prep_started")
  prepStarted,
  @JsonValue("prep_finished")
  prepFinished,
  @JsonValue("snoozed")
  snoozed,
  @JsonValue("departed")
  departed,
  @JsonValue("item_checked")
  itemChecked,
  @JsonValue("excluded")
  excluded,
}

enum ActionSource {
  @JsonValue("user")
  user,
  @JsonValue("geo")
  geo,
  @JsonValue("system")
  system,
}

/// POST /plans/{id}/actions 배치 요청의 원소 하나.
@freezed
abstract class ActionLogEntry with _$ActionLogEntry {
  const factory ActionLogEntry({
    required String clientEventId,
    required ActionType actionType,
    // 기기 시각(deviceTs)은 UTC(Z)로 직렬화한다. 로컬 DateTime의
    // toIso8601String()은 오프셋/Z가 없어 BE(Instant) 파싱이 400으로
    // 실패한다. updatePlan/reportArrival과 동일한 toUtc() 규약.
    @JsonKey(toJson: _deviceTsToJson) required DateTime deviceTs,
    required ActionSource actionSource,
    double? confidence, // actionSource: geo일 때만. 좌표는 포함하지 않는다.
  }) = _ActionLogEntry;

  factory ActionLogEntry.fromJson(Map<String, dynamic> json) =>
      _$ActionLogEntryFromJson(json);
}

/// deviceTs를 오프셋 포함 ISO-8601 문자열로 변환. TR-02 명세는 "Z만 오는 값은
/// 422"라고 규정하나 실제 재현된 적은 없다(PR #3 참고). 명세를 따라
/// "+00:00" 오프셋을 명시한다.
String _deviceTsToJson(DateTime dt) {
  final utc = dt.toUtc();
  final y = utc.year.toString().padLeft(4, "0");
  final mo = utc.month.toString().padLeft(2, "0");
  final d = utc.day.toString().padLeft(2, "0");
  final h = utc.hour.toString().padLeft(2, "0");
  final mi = utc.minute.toString().padLeft(2, "0");
  final s = utc.second.toString().padLeft(2, "0");
  final ms = utc.millisecond.toString().padLeft(3, "0");
  return "$y-$mo-${d}T$h:$mi:$s.${ms}+00:00";
}

/// POST /plans/{id}/actions 응답. 배치이므로 accepted/duplicated가
/// 정수 카운트다 (API v5.0 §13).
@freezed
abstract class ActionBatchResponse with _$ActionBatchResponse {
  const factory ActionBatchResponse({
    required int accepted,
    required int duplicated,
    required EventLifecycleStatus eventStatus,
    required Map<String, dynamic> plan,
  }) = _ActionBatchResponse;

  factory ActionBatchResponse.fromJson(Map<String, dynamic> json) =>
      _$ActionBatchResponseFromJson(json);
}
