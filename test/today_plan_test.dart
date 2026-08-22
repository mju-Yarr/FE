import "package:ensom/models/today_plan.dart";
import "package:flutter_test/flutter_test.dart";

/// GET /plans/today 응답이 홈 화면의 단일 출처라, 파싱이 틀리면 히어로 상태와
/// 카드 스택이 통째로 어긋난다.
Map<String, dynamic> _event(String id, String startsAt) => {
  "eventId": id,
  "displayName": "일정 $id",
  "startsAt": startsAt,
  "endsAt": null,
  "timezone": "Asia/Seoul",
  "locationState": "not_required",
  "status": "planned",
  "autoManageExcluded": false,
  "sourceType": "internal",
};

Map<String, dynamic> _response({
  required String homeState,
  required List<Map<String, dynamic>> cards,
  Map<String, dynamic>? wrapSummary,
  List<String> degraded = const [],
}) => {
  "serverNow": "2026-08-22T05:00:00Z",
  "date": "2026-08-22",
  "homeState": homeState,
  "cards": cards,
  "wrapSummary": wrapSummary,
  "degraded": degraded,
};

void main() {
  test("서버가 준 상태를 그대로 쓴다", () {
    final plan = TodayPlan.fromJson(
      _response(
        homeState: "depart",
        cards: [
          {
            "state": "depart",
            "event": _event("a", "2026-08-22T05:30:00Z"),
            "plan": null,
          },
        ],
      ),
    );

    expect(plan.homeState, HomeCardState.depart);
    expect(plan.homeState.badge, "출발 임박");
    expect(plan.cards.single.state, HomeCardState.depart);
    expect(plan.cards.single.plan, isNull);
    expect(plan.date, "2026-08-22");
  });

  test("6상태 배지 문구가 프로토타입과 같다", () {
    expect(HomeCardState.ease.badge, "여유");
    expect(HomeCardState.start.badge, "준비 시작");
    expect(HomeCardState.depart.badge, "출발 임박");
    expect(HomeCardState.rush.badge, "촉박");
    expect(HomeCardState.wellness.badge, "웰니스");
    expect(HomeCardState.wrap.badge, "오늘 마무리");
  });

  test("caution 톤은 촉박에만 쓴다", () {
    expect(HomeCardState.rush.isCaution, isTrue);
    for (final state in HomeCardState.values.where(
      (s) => s != HomeCardState.rush,
    )) {
      expect(state.isCaution, isFalse, reason: "${state.name}은 중립 배지여야 한다");
    }
  });

  test("모르는 상태가 와도 홈이 비지 않는다", () {
    final plan = TodayPlan.fromJson(
      _response(homeState: "brand_new_state", cards: const []),
    );
    expect(plan.homeState, HomeCardState.ease);
  });

  test("첫 장이 히어로, 나머지가 겹친 카드다", () {
    final plan = TodayPlan.fromJson(
      _response(
        homeState: "start",
        cards: [
          {"state": "start", "event": _event("a", "2026-08-22T05:30:00Z")},
          {"state": "ease", "event": _event("b", "2026-08-22T08:00:00Z")},
          {"state": "ease", "event": _event("c", "2026-08-22T10:00:00Z")},
        ],
      ),
    );

    expect(plan.hero!.event.eventId, "a");
    expect(plan.stacked.map((c) => c.event.eventId), ["b", "c"]);
    expect(plan.isEmpty, isFalse);
  });

  test("wrap 상태에서는 카드를 겹치지 않는다", () {
    // §3 S-06 — "wrap 상태에서는 겹친 카드를 두지 않고 카드가 폭을 가득 쓴다".
    final plan = TodayPlan.fromJson(
      _response(
        homeState: "wrap",
        cards: [
          {"state": "wrap", "event": _event("a", "2026-08-22T01:00:00Z")},
          {"state": "wrap", "event": _event("b", "2026-08-22T03:00:00Z")},
        ],
      ),
    );

    expect(plan.homeState, HomeCardState.wrap);
    expect(plan.stacked, isEmpty);
  });

  test("일정이 없으면 빈 상태다", () {
    final plan = TodayPlan.fromJson(
      _response(homeState: "ease", cards: const []),
    );
    expect(plan.isEmpty, isTrue);
    expect(plan.hero, isNull);
    expect(plan.stacked, isEmpty);
  });

  test("degraded는 그대로 전달된다", () {
    final plan = TodayPlan.fromJson(
      _response(
        homeState: "ease",
        cards: const [],
        degraded: ["environment_unavailable"],
      ),
    );
    expect(plan.degraded, ["environment_unavailable"]);
  });

  test("카운트다운은 기기 시계가 아니라 서버 시각을 기준으로 센다", () {
    // 기기 시계가 1시간 빠른 상황을 흉내 낸다: 응답 수신 시각을 지금으로 두고
    // 서버 시각은 그보다 1시간 뒤다.
    final now = DateTime.now();
    final plan = TodayPlan(
      serverNow: now.add(const Duration(hours: 1)),
      date: "2026-08-22",
      homeState: HomeCardState.start,
      cards: const [],
      receivedAt: now,
    );

    final remaining = plan.remainingUntil(now.add(const Duration(hours: 2)));
    // 서버 기준으로는 1시간 남았다. 기기 시계로 재면 2시간이 나온다.
    expect(remaining!.inMinutes, closeTo(60, 1));
  });

  test("대상 시각이 없으면 카운트다운도 없다", () {
    final plan = TodayPlan(
      serverNow: DateTime.now(),
      date: "2026-08-22",
      homeState: HomeCardState.ease,
      cards: const [],
    );
    expect(plan.remainingUntil(null), isNull);
  });
}
