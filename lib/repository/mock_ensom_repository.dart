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

class MockEnsomRepository implements EnsomRepository {
  // -- 일정 --------------------------------------------------------
  @override
  Future<TodayPlan> fetchTodayPlan() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final event = await fetchEvent("mock-event-1");
    return TodayPlan(
      serverNow: DateTime.now(),
      date: DateTime.now().toIso8601String().substring(0, 10),
      homeState: HomeCardState.start,
      cards: [TodayPlanCard(state: HomeCardState.start, event: event)],
    );
  }

  @override
  Future<Event?> fetchNextEvent() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return fetchEvent("mock-event-1");
  }

  @override
  Future<Event> fetchEvent(String eventId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return Event(
      eventId: eventId,
      title: "강남역 미팅",
      displayLabel: "강남역 미팅",
      displayName: "강남역 미팅",
      startsAt: DateTime.now().add(const Duration(hours: 3)),
      endsAt: DateTime.now().add(const Duration(hours: 4)),
      locationState: LocationState.requiredResolved,
      destinationName: "강남역",
      destinationLat: 37.498,
      destinationLng: 127.027,
      anchor: EventAnchor.arriveBy,
      sourceType: EventSourceType.internal,
      status: EventLifecycleStatus.notified,
    );
  }

  @override
  Future<List<Event>> fetchEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final next = await fetchNextEvent();
    return next == null ? [] : [next];
  }

  @override
  Future<Event> createEvent(
    Event event, {
    String? originPlaceId,
    String? selectedRouteOptionId,
    String? writeToCalendarSourceId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return event;
  }

  @override
  Future<Event> updateEvent(String eventId, Event event) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return event;
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<List<PendingEventReview>> fetchPendingReviews({
    required DateTime from,
    required DateTime to,
  }) async => const [];

  @override
  Future<void> reviewEventClassification(
    String eventId,
    EventClassificationReview review, {
    String? reviewId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // -- 계획 --------------------------------------------------------
  @override
  Future<Plan> fetchLatestPlan(String eventId) => _mockPlan();

  @override
  Future<Plan> fetchPlan(String planId) => _mockPlan();

  @override
  Future<Plan> recalculatePlan(String eventId) => _mockPlan();

  @override
  Future<Plan> updatePlan(
    String planId, {
    DateTime? prepStartAt,
    String? originPlaceId,
  }) => _mockPlan();

  Future<Plan> _mockPlan() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final now = DateTime.now();
    return Plan(
      planId: "mock-plan-1",
      eventId: "mock-event-1",
      revisionNo: 3,
      calcVersion: "3.1.0",
      planStatus: PlanStatus.active,
      eventStatus: EventLifecycleStatus.notified,
      feasible: true,
      predictionConfidence: "high",
      prepStartAt: now.add(const Duration(hours: 2)),
      recommendedDepartAt: now.add(const Duration(hours: 2, minutes: 45)),
      targetArriveAt: now.add(const Duration(hours: 3, minutes: 25)),
      breakdown: const PlanBreakdown(
        estimatedPrepMinutes: 35,
        extraPrepMinutes: 5,
        personalRoutineMinutes: 10,
        travelMinutes: 42,
        trafficBufferMinutes: 7,
        arrivalBufferMinutes: 10,
      ),
      reasons: const [
        PlanReason(
          field: "estimatedPrepMinutes",
          source: "estimate",
          adjusted: true,
          text: "최근 8회 기록 기준, 초기 설정보다 +5분",
          sampleCount: 8,
        ),
        PlanReason(
          field: "personalRoutineMinutes",
          source: "prepRule",
          adjusted: false,
          text: "렌즈·화장 (등록한 루틴)",
        ),
        PlanReason(
          field: "travelMinutes",
          source: "routeProvider",
          adjusted: false,
          text: "외부 지도 API 기준",
        ),
        PlanReason(
          field: "extraPrepMinutes",
          source: "environment",
          adjusted: false,
          text: "출발 시간 강수 확률 70%",
        ),
      ],
      checklist: const [
        ChecklistItem(
          planPrepItemId: "ppi1",
          itemName: "영양제",
          actionType: PrepActionType.consume,
          sourceType: ChecklistSourceType.rule,
          completionStatus: ChecklistCompletionStatus.pending,
        ),
        ChecklistItem(
          planPrepItemId: "ppi2",
          itemName: "선크림",
          actionType: PrepActionType.carry,
          sourceType: ChecklistSourceType.rule,
          completionStatus: ChecklistCompletionStatus.pending,
          reason: "자외선 높음 · 야외 45분",
        ),
        ChecklistItem(
          planPrepItemId: "ppi3",
          itemName: "렌즈·화장",
          actionType: PrepActionType.timedRoutine,
          sourceType: ChecklistSourceType.rule,
          completionStatus: ChecklistCompletionStatus.pending,
          appliedMinutes: 10,
        ),
        ChecklistItem(
          planPrepItemId: "ppi4",
          itemName: "복용약",
          actionType: PrepActionType.consume,
          sourceType: ChecklistSourceType.rule,
          completionStatus: ChecklistCompletionStatus.pending,
          isSensitive: true,
        ),
      ],
      wellnessActions: const [
        WellnessAction(
          wellnessActionId: "wa1",
          wellnessTopic: "uv",
          actionCode: "sunscreen",
          actionLabel: "출발 전 선크림 확인",
          displayRank: 1,
          reasonSnapshot: "자외선 높음 · 예상 야외 이동 45분",
          completionStatus: WellnessActionCompletionStatus.proposed,
        ),
        WellnessAction(
          wellnessActionId: "wa2",
          wellnessTopic: "hydration",
          actionCode: "hydration",
          actionLabel: "물 챙기기",
          displayRank: 2,
          reasonSnapshot: "체감온도 31℃",
          completionStatus: WellnessActionCompletionStatus.proposed,
        ),
      ],
      wellness: const WellnessSummary(
        wisScore: 72,
        wisBand: WisBand.high,
        weightVersion: "w1",
        eventArmed: true,
      ),
      context: const PlanContext(
        uvIndex: 8,
        pm10: 45,
        pm25: 22,
        feelsLike: 31.2,
        precipitationProb: 70,
        estimatedOutdoorMinutes: 45,
        weatherProvider: "kma",
        airProvider: "airkorea",
      ),
      selectedRouteOptionId: "r1",
      degraded: const [],
    );
  }

  // -- 경로 --------------------------------------------------------
  @override
  Future<List<RouteOption>> fetchRouteOptions(String planId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final base = DateTime.now();
    return [
      RouteOption(
        routeOptionId: "r1",
        routeRank: 1,
        routeType: RouteType.fastest,
        totalMinutes: 42,
        walkMinutes: 11,
        transferCount: 1,
        departAt: base,
        arriveAt: base.add(const Duration(minutes: 42)),
      ),
      RouteOption(
        routeOptionId: "r2",
        routeRank: 2,
        routeType: RouteType.leastWalk,
        totalMinutes: 47,
        walkMinutes: 4,
        transferCount: 2,
        departAt: base,
        arriveAt: base.add(const Duration(minutes: 47)),
      ),
      RouteOption(
        routeOptionId: "r3",
        routeRank: 3,
        routeType: RouteType.leastTransfer,
        totalMinutes: 51,
        walkMinutes: 9,
        transferCount: 0,
        departAt: base,
        arriveAt: base.add(const Duration(minutes: 51)),
      ),
    ];
  }

  @override
  Future<Plan> selectRoute(String planId, String routeOptionId) => _mockPlan();

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
  }) => fetchRouteOptions("search");

  // -- 설정 ---------------------------------------------------------
  @override
  Future<void> updateSettings(Map<String, dynamic> patch) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // -- 맞춤 준비 항목 ------------------------------------------------
  @override
  Future<List<PrepItem>> fetchPrepItems() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      PrepItem(id: "pi1", label: "영양제", kind: PrepKind.consume, fromChip: true),
      PrepItem(id: "pi2", label: "물 텀블러", kind: PrepKind.carry, fromChip: true),
    ];
  }

  @override
  Future<PrepItem> createPrepItem(PrepItem item) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return item;
  }

  @override
  Future<PrepItem> updatePrepItem(String id, PrepItem item) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return item;
  }

  @override
  Future<void> deletePrepItem(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // -- 알림 --------------------------------------------------------
  @override
  Future<List<AppNotification>> fetchTodayNotifications() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    return [
      AppNotification(
        notificationId: "n1",
        planId: "plan-1",
        notificationCategory: NotificationCategory.time,
        notificationType: NotificationType.relaxed,
        slot: "A",
        scheduledAt: now.subtract(const Duration(minutes: 20)),
        sentAt: now.subtract(const Duration(minutes: 20)),
        deliveryStatus: DeliveryStatus.delivered,
        body: "20분 뒤 준비를 시작할 예정입니다.",
        triggerReason: "준비 시작 20분 전",
        reaction: "prep_started",
      ),
      AppNotification(
        notificationId: "n2",
        planId: "plan-1",
        notificationCategory: NotificationCategory.time,
        notificationType: NotificationType.disruption,
        slot: "C",
        sentAt: now.subtract(const Duration(minutes: 5)),
        deliveryStatus: DeliveryStatus.delivered,
        body: "지하철 지연으로 출발 권장 시각이 7분 빨라졌습니다.",
        triggerReason: "교통 지연 +8분",
      ),
      AppNotification(
        notificationId: "n3",
        planId: "plan-1",
        notificationCategory: NotificationCategory.wellness,
        notificationType: NotificationType.wellnessEvent,
        slot: "W",
        sentAt: now.subtract(const Duration(minutes: 90)),
        deliveryStatus: DeliveryStatus.delivered,
        body: "야외 이동이 계속되고 있어요. 설정한 시간이 지났다면 선크림을 다시 확인해 보세요.",
        triggerReason: "자외선 높음 · 설정 주기 120분 도달",
        reaction: "completed",
      ),
    ];
  }

  @override
  Future<void> respondToNotification(
    String notificationId,
    NotificationReaction reaction,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // -- 웰니스 ------------------------------------------------------
  @override
  Future<void> resolveChecklistItem(
    String planId,
    String planPrepItemId,
    ChecklistCompletionStatus status, {
    required String clientEventId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> resolveWellnessAction(
    String planId,
    String wellnessActionId,
    WellnessActionCompletionStatus status, {
    required String clientEventId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<DailyWellnessSummary?> fetchDailySummary(String date) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return DailyWellnessSummary(
      summaryId: "mock-summary-1",
      summaryDate: date,
      eventCount: 3,
      totalOutdoorMinutes: 43,
      outdoorSource: "estimated",
      dwlBand: DwlBand.mid,
      cardScenario: "exposure",
      message: "자외선이 높은 시간대의 예상 야외 이동이 길었어요. 지금은 수분을 보충하고 편안하게 쉬어주세요.",
    );
  }

  @override
  Future<WeeklySummary> fetchWeeklySummary(String date) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final anchor = DateTime.parse(date);
    final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
    return WeeklySummary(
      weekStart: monday,
      weekEnd: monday.add(const Duration(days: 6)),
      managedEventCount: 8,
      onTimeRate: .75,
      onTimeSampleCount: 8,
      averageSlackMinutes: 7,
      averageSlackSampleCount: 8,
      prepAccuracy: List.generate(
        5,
        (index) => PrepAccuracyPoint(
          date: monday.add(Duration(days: index)),
          predictedMinutes: 28 + index,
          actualMinutes: 25 + index * 2,
          sampleCount: 1,
        ),
      ),
      wellnessCompletionRate: .75,
      wellnessProposedCount: 8,
      wellnessCompletedCount: 6,
      outdoorMinutes: 260,
      outdoorSampleCount: 8,
      outdoorSource: "estimated",
    );
  }

  @override
  Future<void> markDailySummaryViewed(String summaryId) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<List<WellnessPref>> fetchWellnessPrefs() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      WellnessPref(topic: "uv", isEnabled: true, remindIntervalMinutes: 120),
      WellnessPref(topic: "pm", isEnabled: true, remindIntervalMinutes: 180),
      WellnessPref(topic: "heat", isEnabled: false, remindIntervalMinutes: 90),
      WellnessPref(
        topic: "precipitation",
        isEnabled: true,
        remindIntervalMinutes: 60,
      ),
      WellnessPref(
        topic: "hydration",
        isEnabled: true,
        remindIntervalMinutes: 120,
      ),
    ];
  }

  @override
  Future<void> updateWellnessPrefs(List<WellnessPref> prefs) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // -- 행동 기록 -----------------------------------------------------
  @override
  Future<ActionBatchResponse> submitActions(
    String planId,
    List<ActionLogEntry> actions,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final plan = await _mockPlan();
    return ActionBatchResponse(
      accepted: actions.length,
      duplicated: 0,
      eventStatus: EventLifecycleStatus.preparing,
      plan: plan.toJson(),
    );
  }

  @override
  Future<void> reportArrival(
    String eventId,
    String planId, {
    required String clientEventId,
    required ActionSource source,
    double? confidence,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // -- 도착 결과·사후 평가 ---------------------------------------------
  @override
  Future<EventExecution> fetchExecution(String eventId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    return EventExecution(
      actualPrepStartedAt: now.subtract(const Duration(minutes: 40)),
      actualDepartedAt: now.subtract(const Duration(minutes: 25)),
      actualArrivedAt: now,
      arrivalResult: ArrivalResult.onTime,
      resultSource: "geo",
      actualOutdoorMinutes: 12,
      rushLoadScore: 20,
    );
  }

  @override
  Future<void> submitFeedback(
    String eventId, {
    required PrepTimingAssessment prepTimingAssessment,
    required ArrivalResult arrivalResult,
    required RushAssessment rushAssessment,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // -- 개인화 ------------------------------------------------------
  @override
  Future<List<PrepEstimate>> fetchPrepEstimates() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      PrepEstimate(scopeType: "global", estimatedMinutes: 35, sampleCount: 12),
      PrepEstimate(
        scopeType: "event_kind",
        scopeValue: "저녁 약속",
        estimatedMinutes: 42,
        sampleCount: 5,
      ),
    ];
  }

  @override
  Future<void> revertPersonalization() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> resetPersonalization() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // -- 장소 --------------------------------------------------------
  @override
  Future<List<Place>> fetchPlaces() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      Place(
        placeId: "p1",
        placeType: "home",
        placeName: "집",
        address: "서울시 중구",
        lat: 37.5665,
        lng: 126.9780,
        isPrimary: true,
      ),
    ];
  }

  @override
  Future<List<Bookmark>> fetchBookmarks({String? folder}) async => const [];

  @override
  Future<Bookmark> createBookmark({
    required String placeName,
    String? address,
    required double lat,
    required double lng,
    String? folder,
  }) async => Bookmark(
    bookmarkId: "mock-bookmark",
    placeName: placeName,
    address: address,
    lat: lat,
    lng: lng,
    folder: folder,
  );

  @override
  Future<Bookmark> patchBookmark(
    String bookmarkId, {
    String? placeName,
    String? address,
    String? folder,
    int? sortOrder,
  }) async => Bookmark(
    bookmarkId: bookmarkId,
    placeName: placeName ?? "북마크",
    address: address,
    lat: 37.5,
    lng: 127.0,
    folder: folder,
    sortOrder: sortOrder ?? 0,
  );

  @override
  Future<void> bulkDeleteBookmarks(List<String> bookmarkIds) async {}

  @override
  Future<void> deleteBookmark(String bookmarkId) async {}

  @override
  Future<List<RecentDestination>> fetchRecentDestinations({
    int limit = 20,
  }) async => const [];

  @override
  Future<void> clearRecentDestinations() async {}

  @override
  Future<Place> registerPlace(Place place) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return place;
  }

  @override
  Future<void> deletePlace(String placeId) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // -- 캘린더 연동 ---------------------------------------------------
  @override
  Future<void> syncCalendar() async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<List<CalendarConnection>> fetchCalendarConnections() async => const [];

  @override
  Future<CalendarSource> setCalendarSourceSync(
    String sourceId,
    bool enabled,
  ) async => CalendarSource(
    calendarSourceId: sourceId,
    displayName: "내 캘린더",
    writable: true,
    defaultSource: true,
    syncEnabled: enabled,
  );

  @override
  Future<CalendarSource> setDefaultCalendarSource(String sourceId) async =>
      CalendarSource(
        calendarSourceId: sourceId,
        displayName: "내 캘린더",
        writable: true,
        defaultSource: true,
        syncEnabled: true,
      );

  // -- 계정 --------------------------------------------------------
  @override
  Future<void> deleteAccount() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
