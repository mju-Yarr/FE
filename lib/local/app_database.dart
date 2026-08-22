import "package:drift/drift.dart";

import "connection/connection.dart";

part "app_database.g.dart";

/// 오프라인 행동 큐. ActionLogEntry를 필드별로 쪼개 저장하지 않고
/// payloadJson 하나에 통째로 직렬화해서 담는다 -- enum의 Dart 이름과
/// 서버 JSON 값이 다른 경우(예: ActionType.prepStarted -> "prep_started")
/// 를 수동으로 문자열 매핑하다가 틀릴 위험을 원천적으로 없애기 위해서다.
/// 저장/복원 모두 ActionLogEntry.toJson()/fromJson()에 위임한다.
class OfflineActionQueue extends Table {
  /// (userId, clientEventId) UNIQUE가 서버 쪽 멱등성 키다(TR-03).
  /// 로컬에서도 이 값을 PK로 둬서 같은 사건이 중복 큐잉되지 않게 한다.
  TextColumn get clientEventId => text()();
  TextColumn get planId => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get queuedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {clientEventId};
}

@DriftDatabase(tables: [OfflineActionQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 1;
}
