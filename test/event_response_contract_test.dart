import "package:ensom/models/event.dart";
import "package:flutter_test/flutter_test.dart";

Map<String, dynamic> _eventJson({String? anchorMode, String? anchor}) => {
  "eventId": "event-1",
  "displayName": "회의",
  "startsAt": "2026-08-24T09:00:00Z",
  "locationState": "not_required",
  "anchorMode": ?anchorMode,
  "anchor": ?anchor,
};

void main() {
  test("표준 anchorMode의 depart_at을 출발 기준으로 파싱한다", () {
    final event = Event.fromJson(_eventJson(anchorMode: "depart_at"));
    expect(event.anchor, EventAnchor.departAt);
  });

  test("legacy anchor 응답도 계속 파싱한다", () {
    final event = Event.fromJson(_eventJson(anchor: "depart_at"));
    expect(event.anchor, EventAnchor.departAt);
  });

  test("두 키가 함께 오면 표준 anchorMode를 우선한다", () {
    final event = Event.fromJson(
      _eventJson(anchorMode: "depart_at", anchor: "arrive_by"),
    );
    expect(event.anchor, EventAnchor.departAt);
  });

  test("두 키가 모두 없으면 기존 도착 기준 기본값을 유지한다", () {
    final event = Event.fromJson(_eventJson());
    expect(event.anchor, EventAnchor.arriveBy);
  });
}
