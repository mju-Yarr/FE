/// BE `CalendarSourceResponse` — 연결된 캘린더 하나(내 캘린더, 공휴일 등).
class CalendarSource {
  const CalendarSource({
    required this.calendarSourceId,
    required this.displayName,
    required this.writable,
    required this.defaultSource,
    required this.syncEnabled,
  });

  factory CalendarSource.fromJson(Map<String, dynamic> json) => CalendarSource(
    calendarSourceId: json["calendarSourceId"] as String,
    displayName: json["displayName"] as String? ?? "이름 없는 캘린더",
    // BE 필드명이 writable/defaultSource다. isWritable/isDefault가 아니다.
    writable: json["writable"] as bool? ?? false,
    defaultSource: json["defaultSource"] as bool? ?? false,
    syncEnabled: json["syncEnabled"] as bool? ?? false,
  );

  final String calendarSourceId;
  final String displayName;

  /// 쓰기 가능한 소스만 기본 기록 캘린더가 될 수 있다(BE
  /// CALENDAR_SOURCE_NOT_WRITABLE). 공휴일 캘린더 같은 읽기 전용은 제외된다.
  final bool writable;

  /// 일정을 기록할 기본 캘린더인지.
  final bool defaultSource;

  /// 이 캘린더의 일정을 가져올지.
  final bool syncEnabled;
}

/// BE `CalendarConnectionSummaryResponse` — GET /v1/calendar/connections.
class CalendarConnection {
  const CalendarConnection({
    required this.calendarConnectionId,
    required this.provider,
    required this.externalAccountId,
    required this.connectedAt,
    this.lastSyncedAt,
    this.sources = const [],
  });

  factory CalendarConnection.fromJson(Map<String, dynamic> json) =>
      CalendarConnection(
        calendarConnectionId: json["calendarConnectionId"] as String,
        provider: json["provider"] as String? ?? "google",
        externalAccountId: json["externalAccountId"] as String? ?? "",
        connectedAt: DateTime.parse(json["connectedAt"] as String),
        lastSyncedAt: json["lastSyncedAt"] == null
            ? null
            : DateTime.parse(json["lastSyncedAt"] as String),
        sources: (json["sources"] as List<dynamic>? ?? const [])
            .map((s) => CalendarSource.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  final String calendarConnectionId;
  final String provider;
  final String externalAccountId;
  final DateTime connectedAt;

  /// 아직 한 번도 동기화하지 않았으면 null. "동기화한 적 없음"과 "방금 했음"을
  /// 구분해야 해서 0으로 채우지 않는다.
  final DateTime? lastSyncedAt;

  /// 기본 기록 캘린더가 먼저, 그다음 이름순으로 서버가 정렬해서 준다.
  final List<CalendarSource> sources;
}

/// 연결 전체에서 일정을 기록할 수 있는 소스만 모은다. S-10의 "저장할 캘린더
/// 선택"이 쓰는 목록이다.
extension CalendarConnectionListX on List<CalendarConnection> {
  List<CalendarSource> get writableSources =>
      expand((c) => c.sources).where((s) => s.writable).toList();

  CalendarSource? get defaultWritableSource {
    for (final source in writableSources) {
      if (source.defaultSource) return source;
    }
    return null;
  }
}
