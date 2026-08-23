import "ensom_repository.dart";
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
import "../network/api_client.dart";

/// API v5.0 기준 실제 구현체. 이번 PR(M1)이 화면에서 실제로 쓰는
/// 5개 엔드포인트만 진짜로 붙였다:
///   GET  /events/next
///   GET  /events/{eventId}/plans/latest
///   POST /plans/{planId}/actions
///   GET  /plans/{planId}/routes
///   POST /plans/{planId}/routes/select
///
/// 나머지 메서드(장소·맞춤준비항목·알림·개인화·캘린더연동·계정)는
/// 각각 다른 브랜치 범위(주로 feat/fe-auth-onboarding, feat/fe-wellness,
/// feat/fe-map-summary-settings)라 UnimplementedError로 남겨둔다 --
/// 이 리포지토리를 그 화면에 조기 연결하면 조용히 죽는 대신 바로
/// 터지게 하기 위함이다.

/// API 명세 §1.5 TR-02는 오프셋 포함 ISO-8601을 요구하고 "Z만 오면 422"라고
/// 적혀 있다(이 422가 실제로 재현된 적은 없음 — PR #3에서 POST /events 바디는
/// Z suffix로도 201이 확인됨). 명세를 따라 "+00:00" 오프셋을 명시해 보낸다.
String _toOffsetIso8601(DateTime dt) {
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

class ApiEnsomRepository implements EnsomRepository {
  ApiEnsomRepository(this._client);

  final ApiClient _client;

  // -- 일정 (M1에서 쓰는 것만 구현) -----------------------------------
  @override
  Future<TodayPlan> fetchTodayPlan() async {
    final json = await _client.get<Map<String, dynamic>>("/plans/today");
    return TodayPlan.fromJson(json);
  }

  @override
  Future<Event?> fetchNextEvent() async {
    try {
      final json = await _client.get<Map<String, dynamic>>("/events/next");
      return Event.fromJson(json);
    } on ApiException catch (e) {
      if (e.code == "NEXT_EVENT_NOT_FOUND" || e.code == "EVENT_NOT_FOUND") {
        return null;
      }
      rethrow;
    }
  }

  // -- 계획 --------------------------------------------------------
  @override
  Future<Plan> fetchLatestPlan(String eventId) async {
    final json = await _client.get<Map<String, dynamic>>(
      "/events/$eventId/plans/latest",
    );
    return Plan.fromJson(json);
  }

  @override
  Future<Plan> fetchPlan(String planId) async {
    final json = await _client.get<Map<String, dynamic>>("/plans/$planId");
    return Plan.fromJson(json);
  }

  @override
  Future<Plan> recalculatePlan(String eventId) async {
    final json = await _client.post<Map<String, dynamic>>(
      "/events/$eventId/plan/recalculate",
      body: {"reason": "user_request"},
    );
    return Plan.fromJson(json);
  }

  // -- 경로 --------------------------------------------------------
  @override
  Future<List<RouteOption>> fetchRouteOptions(String planId) async {
    final json = await _client.get<List<dynamic>>("/plans/$planId/routes");
    return json
        .map((e) => RouteOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Plan> selectRoute(String planId, String routeOptionId) async {
    final json = await _client.post<Map<String, dynamic>>(
      "/plans/$planId/routes/select",
      body: {"routeOptionId": routeOptionId},
    );
    return Plan.fromJson(json);
  }

  @override
  Future<List<RouteOption>> fetchRouteSearch({
    double? originLat,
    double? originLng,
    String? originPlaceId,
    required double destLat,
    required double destLng,
    required String destName,
    required EventAnchor anchorMode,
    required DateTime at,
  }) async {
    try {
      final json = await _client.get<List<dynamic>>(
        "/routes/search",
        query: {
          if (originPlaceId != null) "originPlaceId": originPlaceId,
          if (originLat != null) "originLat": originLat,
          if (originLng != null) "originLng": originLng,
          "destLat": destLat,
          "destLng": destLng,
          "destName": destName,
          "anchorMode": anchorMode == EventAnchor.departAt
              ? "depart_at"
              : "arrive_by",
          "at": _toOffsetIso8601(at),
        },
      );
      return json
          .map((e) => RouteOption.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      // BE에 엔드포인트가 아직 없으면 404 → 빈 리스트로 저하 동작.
      // UI에서 빈 리스트를 받으면 "경로 검색을 사용할 수 없어요" 안내 표시.
      if (e.statusCode == 404 || e.code == "NOT_FOUND") return [];
      rethrow;
    }
  }

  // -- 행동 기록 -----------------------------------------------------
  @override
  Future<ActionBatchResponse> submitActions(
    String planId,
    List<ActionLogEntry> actions,
  ) async {
    final json = await _client.post<Map<String, dynamic>>(
      "/plans/$planId/actions",
      body: {"actions": actions.map((a) => a.toJson()).toList()},
    );
    return ActionBatchResponse.fromJson(json);
  }

  // -- 웰니스 (resolve만 구현 -- 화면에서 이미 호출하므로) ----------------
  @override
  Future<void> resolveChecklistItem(
    String planId,
    String planPrepItemId,
    ChecklistCompletionStatus status, {
    required String clientEventId,
  }) async {
    await _client.post<Map<String, dynamic>>(
      "/plans/$planId/prep-items/$planPrepItemId/resolve",
      body: {"completionStatus": status.name, "clientEventId": clientEventId},
    );
  }

  @override
  Future<void> resolveWellnessAction(
    String planId,
    String wellnessActionId,
    WellnessActionCompletionStatus status, {
    required String clientEventId,
  }) async {
    await _client.post<Map<String, dynamic>>(
      "/plans/$planId/wellness-actions/$wellnessActionId/resolve",
      body: {"completionStatus": status.name, "clientEventId": clientEventId},
    );
  }

  // ================================================================
  // 설정 (SET-03, ONB-01) — PATCH /me/settings
  // ================================================================

  @override
  Future<void> updateSettings(Map<String, dynamic> patch) async {
    // BE SettingsRequest는 전체 필드를 요구한다 (부분 patch 불가).
    // 현재 값을 먼저 읽고 변경분을 merge해서 전송한다.
    final current = await _client.get<Map<String, dynamic>>("/me/settings");
    final merged = {...current, ...patch};
    await _client.patch<Map<String, dynamic>>("/me/settings", body: merged);
  }

  // ================================================================
  // 맞춤 준비 항목 (ONB-01, SET-02, PLAN-05)
  // API 명세 §6: POST /prep-items
  // ================================================================

  @override
  Future<List<PrepItem>> fetchPrepItems() async {
    final json = await _client.get<List<dynamic>>("/prep-items");
    return json
        .map((e) => PrepItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PrepItem> createPrepItem(PrepItem item) async {
    final json = await _client.post<Map<String, dynamic>>(
      "/prep-items",
      body: _prepItemToRequestBody(item),
    );
    return PrepItem.fromJson(json);
  }

  @override
  Future<PrepItem> updatePrepItem(String id, PrepItem item) async {
    final json = await _client.patch<Map<String, dynamic>>(
      "/prep-items/$id",
      body: _prepItemToRequestBody(item),
    );
    return PrepItem.fromJson(json);
  }

  @override
  Future<void> deletePrepItem(String id) async {
    await _client.delete<Map<String, dynamic>>("/prep-items/$id");
  }

  /// API 명세 §6.1의 요청 바디 구성.
  /// PrepItem 모델의 필드를 서버가 기대하는 camelCase 필드로 변환한다.
  Map<String, dynamic> _prepItemToRequestBody(PrepItem item) {
    // PrepKind → (ruleCategory, actionType) 매핑
    // API 명세 §6: ruleCategory × actionType 2축 구조
    String ruleCategory;
    String actionType;

    switch (item.kind) {
      case PrepKind.carry:
        ruleCategory = "general_item";
        actionType = "carry";
      case PrepKind.consume:
        // sensitive가 medication 판별 기준 (§6.2: medication → isSensitive 강제)
        ruleCategory = item.sensitive ? "medication" : "supplement";
        actionType = "consume";
      case PrepKind.purchase:
        ruleCategory = "personal_item";
        actionType = "purchase";
      case PrepKind.routine:
        ruleCategory = "routine";
        actionType = "timed_routine";
    }

    return {
      "ruleName": item.label,
      "ruleCategory": ruleCategory,
      "actionType": actionType,
      "ruleTiming": "pre_departure",
      "defaultMinutes": item.kind == PrepKind.routine ? item.extraMin : null,
      "applyEventKind": null,
      "applyTimeBand": null,
      "applyPlaceId": null,
      "applyWeather": null,
      "isRequired": false,
      "isSensitive": item.sensitive,
      "fromChip": item.fromChip,
    };
  }

  // ================================================================
  // 아래부터는 이번 PR 범위 밖. 호출 시 즉시 예외를 던진다.
  // ================================================================

  @override
  Future<Event> fetchEvent(String eventId) async {
    final json = await _client.get<Map<String, dynamic>>("/events/$eventId");
    return Event.fromJson(json);
  }

  @override
  Future<List<Event>> fetchEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    final json = await _client.get<List<dynamic>>(
      "/events",
      query: {
        "from": _toOffsetIso8601(from),
        "to": _toOffsetIso8601(to),
      },
    );
    return json.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// API 명세 §8.1 요청 바디. Event 모델은 응답 전용 필드(eventId,
  /// status 등)도 갖고 있어 toJson()을 그대로 보내지 않고 요청에
  /// 필요한 필드만 추린다. enum → 문자열 변환은 생성된 toJson()의
  /// @JsonValue 매핑을 그대로 재사용한다(Dart 필드명 "anchor"만 API
  /// 필드명 "anchorMode"로 다시 매핑).
  @override
  Future<Event> createEvent(
    Event event, {
    String? originPlaceId,
    String? selectedRouteOptionId,
    String? writeToCalendarSourceId,
  }) async {
    final ej = event.toJson();
    final json = await _client.post<Map<String, dynamic>>(
      "/events",
      body: {
        "startsAt": ej["startsAt"],
        "endsAt": ej["endsAt"],
        "locationState": ej["locationState"],
        if (event.destinationName != null)
          "destinationName": event.destinationName,
        if (event.destinationLat != null)
          "destinationLat": event.destinationLat,
        if (event.destinationLng != null)
          "destinationLng": event.destinationLng,
        "sourceType": ej["sourceType"],
        "anchorMode": ej["anchor"],
        if (originPlaceId != null) "originPlaceId": originPlaceId,
        if (selectedRouteOptionId != null)
          "selectedRouteOptionId": selectedRouteOptionId,
        if (event.displayLabel != null) "displayLabel": event.displayLabel,
        if (writeToCalendarSourceId != null)
          "writeToCalendarSourceId": writeToCalendarSourceId,
      },
    );
    return Event.fromJson(json);
  }

  @override
  Future<Event> updateEvent(String eventId, Event event) async {
    final ej = event.toJson();
    final json = await _client.patch<Map<String, dynamic>>(
      "/events/$eventId",
      body: {
        "locationState": ej["locationState"],
        if (event.displayLabel != null) "displayLabel": event.displayLabel,
      },
    );
    return Event.fromJson(json);
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await _client.delete<Map<String, dynamic>>("/events/$eventId");
  }

  @override
  Future<List<PendingEventReview>> fetchPendingReviews({
    required DateTime from,
    required DateTime to,
  }) async {
    final json = await _client.get<List<dynamic>>(
      "/events/reviews/pending",
      query: {
        "from": _toOffsetIso8601(from),
        "to": _toOffsetIso8601(to),
      },
    );
    return json
        .map((e) => PendingEventReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> reviewEventClassification(
    String eventId,
    EventClassificationReview review, {
    String? reviewId,
  }) async {
    await _client.post<Map<String, dynamic>>(
      "/events/$eventId/review",
      body: {
        if (reviewId != null) "reviewId": reviewId,
        "questionType": review.questionType,
        "userAnswer": review.userAnswer,
      },
    );
  }

  @override
  Future<Plan> updatePlan(
    String planId, {
    DateTime? prepStartAt,
    String? originPlaceId,
  }) async {
    // API v5.0 §9.5 PATCH /plans/{planId}.
    // 사용자 직접 수정은 서버가 새 리비전을 만든다(revisionNo 증가).
    //
    // 시각 직렬화(TR-02): toUtc().toIso8601String()은 "...Z"를 반환하는데
    // 명세는 오프셋 포함을 요구한다. 이 422가 실제로 재현된 적은 없으나
    // (PR #3에서 POST /events 바디는 Z suffix로도 201 확인) 명세를 따라
    // _toOffsetIso8601()로 "+00:00" 오프셋을 명시한다.
    final json = await _client.patch<Map<String, dynamic>>(
      "/plans/$planId",
      body: {
        if (prepStartAt != null)
          "prepStartAt": _toOffsetIso8601(prepStartAt),
        if (originPlaceId != null) "originPlaceId": originPlaceId,
      },
    );
    return Plan.fromJson(json);
  }

  @override
  Future<List<AppNotification>> fetchTodayNotifications() async {
    final json = await _client.get<List<dynamic>>("/notifications/today");
    return json
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> respondToNotification(
    String notificationId,
    NotificationReaction reaction,
  ) async {
    await _client.post<Map<String, dynamic>>(
      "/notifications/$notificationId/respond",
      body: {"reaction": reaction.name},
    );
  }

  @override
  Future<DailyWellnessSummary?> fetchDailySummary(String date) async {
    try {
      final json = await _client.get<Map<String, dynamic>>(
        "/summary/daily",
        query: {"date": date},
      );
      return DailyWellnessSummary.fromJson(json);
    } on ApiException catch (e) {
      // 관리 일정 0건이면 카드를 만들지 않는다 (숫자를 지어내지 않음)
      if (e.code == "NOT_FOUND" || e.code == "SUMMARY_NOT_GENERATED") {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<WeeklySummary> fetchWeeklySummary(String date) async {
    final json = await _client.get<Map<String, dynamic>>(
      "/summary/weekly",
      query: {"date": date},
    );
    return WeeklySummary.fromJson(json);
  }

  @override
  Future<void> markDailySummaryViewed(String summaryId) async {
    await _client.post<Map<String, dynamic>>(
      "/summary/daily/$summaryId/viewed",
    );
  }

  @override
  Future<List<WellnessPref>> fetchWellnessPrefs() async {
    // BE 응답 형태에 따라 유연하게 대응:
    //   Case A: {"data": {"prefs": [...]}}  → ApiClient unwrap → {"prefs": [...]}
    //   Case B: {"data": [...]}             → ApiClient unwrap → [...]
    //   Case C: {"prefs": [...]}            → ApiClient가 data 키 없으면 body 그대로
    final raw = await _client.get<dynamic>("/me/wellness-prefs");

    List<dynamic> list;
    if (raw is List) {
      // Case B: 배열 직접 반환
      list = raw;
    } else if (raw is Map<String, dynamic>) {
      // Case A/C: {prefs: [...]} 또는 다른 구조
      list = (raw["prefs"] as List<dynamic>?) ?? [];
    } else {
      list = [];
    }

    return list
        .map((e) => WellnessPref.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> updateWellnessPrefs(List<WellnessPref> prefs) async {
    await _client.patch<Map<String, dynamic>>(
      "/me/wellness-prefs",
      body: {"prefs": prefs.map((p) => p.toJson()).toList()},
    );
  }

  @override
  Future<List<PrepEstimate>> fetchPrepEstimates() async {
    // API v5.0 §15 GET /me/personalization. 응답 data.estimates[]를 파싱.
    // MVP는 scopeType "global"만 사용(§15 주석).
    final json = await _client.get<Map<String, dynamic>>("/me/personalization");
    final estimates = (json["estimates"] as List<dynamic>?) ?? const [];
    return estimates
        .map((e) => PrepEstimate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> revertPersonalization() async {
    // 개인화 설정은 특정 event 문맥이 없으므로 사용자의 직전 global 보정 하나를 되돌린다.
    await _client.post<Map<String, dynamic>>("/me/personalization/revert");
  }

  @override
  Future<void> resetPersonalization() async {
    await _client.delete<Map<String, dynamic>>("/me/personalization");
  }

  @override
  Future<List<Place>> fetchPlaces() async {
    // API v5.0 §5 GET /places. api_client가 공통 응답의 data를 벗겨준다.
    final json = await _client.get<List<dynamic>>("/places");
    return json.map((e) => Place.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Bookmark>> fetchBookmarks({String? folder}) async {
    final json = await _client.get<List<dynamic>>(
      "/me/bookmarks",
      query: {if (folder != null && folder.isNotEmpty) "folder": folder},
    );
    return json
        .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Bookmark> createBookmark({
    required String placeName,
    String? address,
    required double lat,
    required double lng,
    String? folder,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      "/me/bookmarks",
      body: {
        "placeName": placeName,
        if (address != null) "address": address,
        "lat": lat,
        "lng": lng,
        if (folder != null) "folder": folder,
      },
    );
    return Bookmark.fromJson(json);
  }

  @override
  Future<Bookmark> patchBookmark(
    String bookmarkId, {
    String? placeName,
    String? address,
    String? folder,
    int? sortOrder,
  }) async {
    final json = await _client.patch<Map<String, dynamic>>(
      "/me/bookmarks/$bookmarkId",
      body: {
        if (placeName != null) "placeName": placeName,
        if (address != null) "address": address,
        if (folder != null) "folder": folder,
        if (sortOrder != null) "sortOrder": sortOrder,
      },
    );
    return Bookmark.fromJson(json);
  }

  @override
  Future<void> bulkDeleteBookmarks(List<String> bookmarkIds) async {
    await _client.post<Map<String, dynamic>>(
      "/me/bookmarks/bulk-delete",
      body: {"bookmarkIds": bookmarkIds},
    );
  }

  @override
  Future<void> deleteBookmark(String bookmarkId) async {
    await _client.delete<Map<String, dynamic>>("/me/bookmarks/$bookmarkId");
  }

  @override
  Future<List<RecentDestination>> fetchRecentDestinations({
    int limit = 20,
  }) async {
    final json = await _client.get<List<dynamic>>(
      "/me/recent-destinations",
      query: {"limit": limit},
    );
    return json
        .map((e) => RecentDestination.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> clearRecentDestinations() async {
    await _client.delete<Map<String, dynamic>>("/me/recent-destinations");
  }

  @override
  Future<Place> registerPlace(Place place) async {
    // API v5.0 §5 POST /places. placeId는 서버가 생성하므로 요청 바디에서 제외.
    // Idempotency-Key는 api_client.post가 자동 부착.
    final json = await _client.post<Map<String, dynamic>>(
      "/places",
      body: {
        "placeType": place.placeType,
        "placeName": place.placeName,
        if (place.address != null) "address": place.address,
        "lat": place.lat,
        "lng": place.lng,
        "isPrimary": place.isPrimary,
      },
    );
    return Place.fromJson(json);
  }

  @override
  Future<void> deletePlace(String placeId) async {
    // API v5.0 §5 DELETE /places/{placeId} — 소프트 삭제.
    await _client.delete<Map<String, dynamic>>("/places/$placeId");
  }

  @override
  Future<void> syncCalendar() async {
    // API v5.0 §7 POST /calendar/sync — 이미 연결된 캘린더의 수동 동기화.
    // (연결 추가는 authCode 기반 POST /calendar/google/connect로,
    //  CalendarSyncScreen이 apiClient로 직접 처리한다 — 별개 흐름)
    // 바디 없음. Idempotency-Key는 api_client.post가 자동 부착.
    await _client.post<Map<String, dynamic>>("/calendar/sync", body: const {});
  }

  @override
  Future<List<CalendarConnection>> fetchCalendarConnections() async {
    final json = await _client.get<List<dynamic>>("/calendar/connections");
    return json
        .map((e) => CalendarConnection.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CalendarSource> setCalendarSourceSync(
    String sourceId,
    bool enabled,
  ) async {
    final json = await _client.patch<Map<String, dynamic>>(
      "/calendar/sources/$sourceId",
      body: {"syncEnabled": enabled},
    );
    return CalendarSource.fromJson(json);
  }

  @override
  Future<CalendarSource> setDefaultCalendarSource(String sourceId) async {
    final json = await _client.post<Map<String, dynamic>>(
      "/calendar/sources/$sourceId/default",
    );
    return CalendarSource.fromJson(json);
  }

  // -- 도착 결과·사후 평가 (REPORT-01, §14) -----------------------------
  @override
  Future<EventExecution> fetchExecution(String eventId) async {
    final json = await _client.get<Map<String, dynamic>>(
      "/events/$eventId/execution",
    );
    return EventExecution.fromJson(json);
  }

  @override
  Future<void> submitFeedback(
    String eventId, {
    required PrepTimingAssessment prepTimingAssessment,
    required ArrivalResult arrivalResult,
    required RushAssessment rushAssessment,
  }) async {
    await _client.post<Map<String, dynamic>>(
      "/events/$eventId/feedback",
      body: {
        "prepTimingAssessment": _prepTimingWireValue[prepTimingAssessment]!,
        "arrivalResult": _arrivalResultWireValue[arrivalResult]!,
        "rushAssessment": _rushWireValue[rushAssessment]!,
      },
    );
  }

  static const _prepTimingWireValue = {
    PrepTimingAssessment.tooEarly: "too_early",
    PrepTimingAssessment.appropriate: "appropriate",
    PrepTimingAssessment.tooLate: "too_late",
  };

  static const _arrivalResultWireValue = {
    ArrivalResult.early: "early",
    ArrivalResult.onTime: "on_time",
    ArrivalResult.rushed: "rushed",
    ArrivalResult.late_: "late",
    ArrivalResult.unknown: "unknown",
  };

  static const _rushWireValue = {
    RushAssessment.notRushed: "not_rushed",
    RushAssessment.rushed: "rushed",
  };

  /// 도착 처리: POST /plans/{planId}/actions (배치 엔드포인트)로 전송.
  /// BE dev에 ARRIVED ActionType이 있으므로 행동 기록 경로를 사용한다.
  /// TRD §9.2: 지오펜스 판정 결과를 서버에 전송.
  @override
  Future<void> reportArrival(
    String eventId,
    String planId, {
    required String clientEventId,
    required ActionSource source,
    double? confidence,
  }) async {
    await _client.post<Map<String, dynamic>>(
      "/plans/$planId/actions",
      body: {
        "actions": [
          {
            "actionType": "ARRIVED",
            "actionSource": source.name.toUpperCase(),
            "deviceTs": _toOffsetIso8601(DateTime.now()),
            "clientEventId": clientEventId,
            if (confidence != null) "confidence": confidence,
          },
        ],
      },
    );
  }

  // -- 계정 --------------------------------------------------------
  @override
  Future<void> deleteAccount() async {
    await _client.delete<Map<String, dynamic>>("/me");
  }
}
