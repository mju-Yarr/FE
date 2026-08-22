import "package:ensom/models/calendar_connection.dart";
import "package:flutter_test/flutter_test.dart";

/// S-41 연동 관리와 S-10 "저장할 캘린더 선택"이 같은 목록을 쓴다. 쓰기 가능
/// 판정이 틀리면 서버가 CALENDAR_SOURCE_NOT_WRITABLE로 되돌린다.
Map<String, dynamic> _source(
  String id, {
  bool writable = true,
  bool defaultSource = false,
  bool syncEnabled = true,
}) => {
  "calendarSourceId": id,
  "displayName": "캘린더 $id",
  "writable": writable,
  "defaultSource": defaultSource,
  "syncEnabled": syncEnabled,
};

Map<String, dynamic> _connection(
  String id, {
  String? lastSyncedAt,
  List<Map<String, dynamic>> sources = const [],
}) => {
  "calendarConnectionId": id,
  "provider": "google",
  "externalAccountId": "$id@example.com",
  "connectedAt": "2026-08-20T00:00:00Z",
  "lastSyncedAt": lastSyncedAt,
  "sources": sources,
};

void main() {
  test("연결과 소스를 서버 필드명 그대로 읽는다", () {
    final connection = CalendarConnection.fromJson(
      _connection(
        "c1",
        lastSyncedAt: "2026-08-22T01:00:00Z",
        sources: [_source("s1", defaultSource: true)],
      ),
    );

    expect(connection.calendarConnectionId, "c1");
    expect(connection.externalAccountId, "c1@example.com");
    expect(connection.lastSyncedAt, isNotNull);
    // BE 필드명은 writable/defaultSource다. isWritable/isDefault로 읽으면
    // 전부 false가 되어 기록 대상을 하나도 못 고른다.
    expect(connection.sources.single.writable, isTrue);
    expect(connection.sources.single.defaultSource, isTrue);
    expect(connection.sources.single.syncEnabled, isTrue);
  });

  test("한 번도 동기화하지 않았으면 lastSyncedAt이 null이다", () {
    final connection = CalendarConnection.fromJson(_connection("c1"));
    // 0으로 채우면 "방금 동기화함"으로 읽힌다.
    expect(connection.lastSyncedAt, isNull);
  });

  test("쓰기 가능한 소스만 기록 대상 후보다", () {
    final connections = [
      CalendarConnection.fromJson(
        _connection(
          "c1",
          sources: [
            _source("writable", defaultSource: true),
            _source("holiday", writable: false),
          ],
        ),
      ),
      CalendarConnection.fromJson(
        _connection("c2", sources: [_source("work")]),
      ),
    ];

    expect(connections.writableSources.map((s) => s.calendarSourceId), [
      "writable",
      "work",
    ]);
    expect(connections.defaultWritableSource!.calendarSourceId, "writable");
  });

  test("기본 기록 캘린더가 없으면 null이다", () {
    final connections = [
      CalendarConnection.fromJson(
        _connection("c1", sources: [_source("a"), _source("b")]),
      ),
    ];
    expect(connections.defaultWritableSource, isNull);
  });

  test("소스가 없는 연결도 목록에 남는다", () {
    // 연결은 됐지만 아직 동기화 전이라 소스가 비어 있을 수 있다. 이때 연결
    // 자체를 감추면 사용자가 해제할 방법이 없어진다.
    final connections = [CalendarConnection.fromJson(_connection("c1"))];
    expect(connections.single.sources, isEmpty);
    expect(connections.writableSources, isEmpty);
  });
}
