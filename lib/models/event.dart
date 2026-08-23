import "package:freezed_annotation/freezed_annotation.dart";
import "plan.dart"; // EventLifecycleStatus

part "event.freezed.dart";
part "event.g.dart";

/// 사용자 지정 장소 필요 여부. 자동 분류(CAL-04)보다 항상 우선한다.
/// API v5.0 §8.1 locationState.
enum LocationState {
  @JsonValue("required_resolved")
  requiredResolved,
  @JsonValue("required_missing")
  requiredMissing,
  @JsonValue("not_required")
  notRequired,
  @JsonValue("undecided")
  undecided,
}

/// 계획 계산의 역산 방향을 결정하는 값 (API v5.0 anchorMode).
enum EventAnchor {
  @JsonValue("arrive_by")
  arriveBy,
  @JsonValue("depart_at")
  departAt,
}

enum EventSourceType {
  @JsonValue("internal")
  internal,
  @JsonValue("external")
  external,
  @JsonValue("map_search")
  mapSearch,
}

/// API v5.0 §8.3. 서버는 외부 캘린더 원문 제목을 저장하지 않는다.
/// title은 클라이언트가 생성 요청 시 참고용으로 잠깐 쓸 뿐 화면에
/// 그리지 않는다 -- 항상 displayName만 렌더링한다. displayName은
/// displayLabel -> destinationName -> "오후 2시 일정" 순으로 서버가
/// 이미 해석해서 채워주므로, 클라이언트가 자체적으로 폴백 문구를
/// 만들 필요가 없다(리뷰 High-2, 지난 라운드의 임시방편 제거).
@freezed
abstract class Event with _$Event {
  const factory Event({
    required String eventId,
    String? title,
    String? displayLabel,
    required String displayName,
    required DateTime startsAt,
    String? timezone,
    // BE EventResponse.endsAt은 nullable이다 — 종료 시각 없이 만든 일정이
    // 그대로 null로 내려온다.
    DateTime? endsAt,
    required LocationState locationState,
    String? destinationName,
    String? destinationAddress,
    double? destinationLat,
    double? destinationLng,
    String? meetingUrl,
    String? eventKind,
    String? calendarSourceId,
    @Default(EventAnchor.arriveBy) EventAnchor anchor,
    @Default(EventSourceType.internal) EventSourceType sourceType,
    EventLifecycleStatus? status,
    bool? autoManageExcluded,
  }) = _Event;

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
}

/// POST /events/{id}/review 요청 바디.
/// 분류 신뢰도가 낮을 때(classificationConfidence < 0.70)만 노출한다.
@freezed
abstract class EventClassificationReview with _$EventClassificationReview {
  const factory EventClassificationReview({
    required String questionType,
    required String userAnswer,
  }) = _EventClassificationReview;

  factory EventClassificationReview.fromJson(Map<String, dynamic> json) =>
      _$EventClassificationReviewFromJson(json);
}
