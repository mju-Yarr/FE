import "package:flutter_riverpod/flutter_riverpod.dart";
import "../local/app_database.dart";
import "../local/offline_action_queue_service.dart";
import "../repository/providers.dart";

/// 앱 전체에서 하나만 열려야 하는 DB 커넥션이라 autoDispose를 안 쓴다.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final offlineActionQueueServiceProvider = Provider<OfflineActionQueueService>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  final repo = ref.watch(ensomRepositoryProvider);
  return OfflineActionQueueService(db: db, repo: repo);
});

/// 앱 시작 시 1회 호출하여 큐에 남아 있는 미전송 행동을 자동 재전송한다.
/// main.dart 또는 홈 화면 진입 시 ref.read(offlineQueueFlushProvider)로 트리거.
///
/// connectivity 변경 시에도 이 provider를 invalidate하면 재실행된다.
final offlineQueueFlushProvider = FutureProvider<void>((ref) async {
  final queue = ref.watch(offlineActionQueueServiceProvider);
  await queue.flushAll();
});
