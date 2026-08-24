import "../models/place.dart";
import "../models/calendar_connection.dart";
import "../models/bookmark.dart";
import "../models/event.dart";
import "../models/pending_event_review.dart";
import "../models/plan.dart";
import "../models/today_plan.dart";
import "../models/prep_item.dart";
import "../models/notification.dart";
import "../models/action_log.dart";
import "../models/daily_wellness_summary.dart";
import "../models/weekly_summary.dart";
import "../models/prep_estimate.dart";
import "../models/wellness_pref.dart";
import "../models/execution.dart";

/// API v5.0 기준. submitAction(단건) -> submitActions(배치)로 개명,
/// resolveChecklistItem/resolveWellnessAction 분리(§12.2, 서로 다른
/// 테이블·enum이라 엔드포인트도 분리됨).
abstract class EnsomRepository {
  // 홈 (S-06) — 히어로 카드 상태는 서버가 판정한다(명세 §7.2).
  Future<TodayPlan> fetchTodayPlan();

  // 일정 (CAL-01, 03, 04, 05)
  Future<Event?> fetchNextEvent();
  Future<Event> fetchEvent(String eventId);
  Future<List<Event>> fetchEvents({
    required DateTime from,
    required DateTime to,
  });
  Future<Event> createEvent(
    Event event, {
    String? originPlaceId,
    String? selectedRouteOptionId,
    String? writeToCalendarSourceId,
  });
  Future<Event> updateEvent(String eventId, Event event);
  Future<void> deleteEvent(String eventId);

  /// S-11 — 동기화가 만든 미해결 분류 질문. 답하지 않은 것만 온다.
  Future<List<PendingEventReview>> fetchPendingReviews({
    required DateTime from,
    required DateTime to,
  });

  /// [reviewId]를 넘기면 서버가 그 질문의 최신 여부를 검증한다(REVIEW_STALE·
  /// REVIEW_ALREADY_CLOSED). 안 넘기면 이 일정의 미답변 질문을 서버가 고른다.
  Future<void> reviewEventClassification(
    String eventId,
    EventClassificationReview review, {
    String? reviewId,
  });

  // 계획 (PLAN-01~05)
  Future<Plan> fetchLatestPlan(String eventId);
  Future<Plan> fetchPlan(String planId);
  Future<Plan> recalculatePlan(String eventId);
  Future<Plan> updatePlan(
    String planId, {
    DateTime? prepStartAt,
    String? originPlaceId,
  });

  // 경로 (MAP-01~04)
  Future<List<RouteOption>> fetchRouteOptions(String planId);
  Future<Plan> selectRoute(String planId, String routeOptionId);

  /// 계획 없이 지도 화면에서 검색 (CAL-05 진입점, §10.3 GET /routes/search).
  /// routeOptionId는 TTL 30분짜리 임시 키이며, POST /events의
  /// selectedRouteOptionId로 넘기면 계획 생성 시점에 확정된다.
  Future<List<RouteOption>> fetchRouteSearch({
    double? originLat,
    double? originLng,
    String? originPlaceId,
    required double destLat,
    required double destLng,
    required String destName,
    required EventAnchor anchorMode,
    required DateTime at,
  });

  // 설정 (SET-03, ONB-01)
  Future<Map<String, dynamic>> fetchSettings();
  Future<void> updateSettings(Map<String, dynamic> patch);

  // 맞춤 준비 항목 (ONB-01, SET-02, PLAN-05)
  Future<List<PrepItem>> fetchPrepItems();
  Future<PrepItem> createPrepItem(PrepItem item);
  Future<PrepItem> updatePrepItem(String id, PrepItem item);
  Future<void> deletePrepItem(String id);

  // 알림 (NOTI-01~05)
  Future<List<AppNotification>> fetchTodayNotifications();
  Future<void> respondToNotification(
    String notificationId,
    NotificationReaction reaction,
  );

  // 웰니스 (WELL-01~06) -- API v5.0 §12.2: 두 경로 분리
  Future<void> resolveChecklistItem(
    String planId,
    String planPrepItemId,
    ChecklistCompletionStatus status, {
    required String clientEventId,
  });
  Future<void> resolveWellnessAction(
    String planId,
    String wellnessActionId,
    WellnessActionCompletionStatus status, {
    required String clientEventId,
  });
  Future<DailyWellnessSummary?> fetchDailySummary(String date);
  Future<WeeklySummary> fetchWeeklySummary(String date);
  Future<void> markDailySummaryViewed(String summaryId);

  // 웰니스 관심 항목 설정 (WELL-06) — GET/PATCH /me/wellness-prefs
  Future<List<WellnessPref>> fetchWellnessPrefs();
  Future<void> updateWellnessPrefs(List<WellnessPref> prefs);

  // 행동 기록 -- API v5.0 §13: 배치 {actions:[...]}, clientEventId로 멱등 보장 (TR-03)
  Future<ActionBatchResponse> submitActions(
    String planId,
    List<ActionLogEntry> actions,
  );

  /// 도착 처리 (지오펜스 ENTER+체류검증 또는 수동 "도착했어요" 버튼).
  /// API v5.0 §13에서 v3.0의 `arrived` ActionType은 제거되고
  /// EVENT_EXECUTION으로 옮겨갔다고만 명시돼 있고, 실제 쓰기 엔드포인트가
  /// 문서에 없다 — 백엔드 확인 필요(TODO, map_screen.dart의 기존 관례와 동일).
  Future<void> reportArrival(
    String eventId,
    String planId, {
    required String clientEventId,
    required ActionSource source,
    double? confidence,
  });

  // 도착 결과·사후 평가 (REPORT-01, §14)
  Future<EventExecution> fetchExecution(String eventId);
  Future<void> submitFeedback(
    String eventId, {
    required PrepTimingAssessment prepTimingAssessment,
    required ArrivalResult arrivalResult,
    required RushAssessment rushAssessment,
  });

  // 개인화 (MODEL-01/02)
  Future<List<PrepEstimate>> fetchPrepEstimates();
  Future<void> revertPersonalization();
  Future<void> resetPersonalization();

  // 장소 (SET-01)
  Future<List<Place>> fetchPlaces();
  // 북마크 (S-30/31) · 최근 목적지 (S-08/S-32)
  Future<List<Bookmark>> fetchBookmarks({String? folder});
  Future<Bookmark> createBookmark({
    required String placeName,
    String? address,
    required double lat,
    required double lng,
    String? folder,
  });

  /// null인 필드는 건드리지 않는다. lat/lng는 둘 다 주거나 둘 다 빼야 한다.
  Future<Bookmark> patchBookmark(
    String bookmarkId, {
    String? placeName,
    String? address,
    String? folder,
    int? sortOrder,
  });

  /// S-31 다중 삭제. 하나라도 남의 것이면 서버가 아무것도 지우지 않고 404다.
  Future<void> bulkDeleteBookmarks(List<String> bookmarkIds);
  Future<void> deleteBookmark(String bookmarkId);

  Future<List<RecentDestination>> fetchRecentDestinations({int limit});
  Future<void> clearRecentDestinations();

  Future<Place> registerPlace(Place place);
  Future<void> deletePlace(String placeId);

  // 캘린더 연동 (CAL-02) · S-41 연동 관리
  Future<void> syncCalendar();
  Future<List<CalendarConnection>> fetchCalendarConnections();
  Future<CalendarSource> setCalendarSourceSync(String sourceId, bool enabled);
  Future<CalendarSource> setDefaultCalendarSource(String sourceId);

  // 계정 (AUTH-04, DATA-01)
  // 로그아웃은 AuthNotifier.logout()(lib/providers/auth_providers.dart)이
  // AuthService를 통해 이미 처리한다 — 여기서 중복 정의하지 않는다.
  Future<void> deleteAccount();
}
