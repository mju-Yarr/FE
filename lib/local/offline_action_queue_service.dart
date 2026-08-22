import "dart:convert";
import "package:uuid/uuid.dart";
import "app_database.dart";
import "../models/action_log.dart";
import "../models/plan.dart";
import "../repository/ensom_repository.dart";

/// TR-03 멱등성의 핵심 조각. clientEventId는 **여기, enqueue 시점에
/// 딱 한 번만** 발급한다. 이후 flush()가 몇 번을 재시도하든(오프라인
/// 반복, 앱 재시작 후 재전송 등) 같은 ID를 그대로 재사용하므로,
/// 서버의 (userId, clientEventId) UNIQUE 제약이 실제로 중복을
/// 흡수할 수 있다.
///
/// 지난 라운드까지는 큐 자체가 없어서 "발급 시점 = 전송 시점"이었다.
/// 이번에 그 둘을 실제로 분리했다.
class OfflineActionQueueService {
  OfflineActionQueueService({
    required AppDatabase db,
    required EnsomRepository repo,
  }) : _db = db,
       _repo = repo;

  final AppDatabase _db;
  final EnsomRepository _repo;
  final _uuid = const Uuid();

  /// 큐에 넣고 즉시 flush를 시도한다. 온라인이면 그대로 서버에
  /// 반영되고, 오프라인이면 큐에 남아 다음 flush(앱 재시작 후
  /// flushAll 등)를 기다린다.
  ///
  /// 반환값이 true면 화면(호출부)이 계획을 새로고침해도 된다는 뜻이다
  /// -- false(오프라인)일 때 무작정 새로고침하면 마지막으로 보여주던
  /// 정상 상태가 에러 화면으로 바뀔 수 있어서, 성공한 경우에만
  /// 새로고침하도록 호출부가 이 값을 보고 판단한다.
  Future<bool> enqueue({
    required String planId,
    required ActionType actionType,
    required ActionSource actionSource,
    double? confidence,
  }) async {
    final entry = ActionLogEntry(
      clientEventId: _uuid.v4(),
      actionType: actionType,
      deviceTs: DateTime.now(),
      actionSource: actionSource,
      confidence: confidence,
    );

    await _db
        .into(_db.offlineActionQueue)
        .insert(
          OfflineActionQueueCompanion.insert(
            clientEventId: entry.clientEventId,
            planId: planId,
            payloadJson: jsonEncode(entry.toJson()),
            queuedAt: DateTime.now(),
          ),
        );

    return _flushPlan(planId);
  }

  /// 앱 재시작·재연결 시 큐 전체를 planId별로 묶어 비운다.
  Future<void> flushAll() async {
    final rows = await _db.select(_db.offlineActionQueue).get();
    final planIds = rows.map((r) => r.planId).toSet();
    for (final planId in planIds) {
      await _flushPlan(planId);
    }
  }

  Future<bool> _flushPlan(String planId) async {
    final rows = await (_db.select(
      _db.offlineActionQueue,
    )..where((t) => t.planId.equals(planId))).get();
    if (rows.isEmpty) return false;

    final actions = rows
        .map(
          (r) => ActionLogEntry.fromJson(
            jsonDecode(r.payloadJson) as Map<String, dynamic>,
          ),
        )
        .toList();

    // API v5.0 §1.7: 행동 배치 최대 100건. chunk 단위로 전송하고
    // 각 chunk 성공 시 해당 행만 삭제한다.
    const chunkSize = 100;
    try {
      for (int i = 0; i < actions.length; i += chunkSize) {
        final chunk = actions.sublist(
          i,
          (i + chunkSize > actions.length) ? actions.length : i + chunkSize,
        );
        final chunkRows = rows.sublist(
          i,
          (i + chunkSize > rows.length) ? rows.length : i + chunkSize,
        );

        await _repo.submitActions(planId, chunk);

        // chunk 성공 → 해당 행 삭제
        for (final row in chunkRows) {
          await (_db.delete(
            _db.offlineActionQueue,
          )..where((t) => t.clientEventId.equals(row.clientEventId))).go();
        }
      }
      return true;
    } catch (_) {
      // 실패(주로 오프라인)면 남은 행은 큐에 유지. 다음 flush를 기다린다.
      return false;
    }
  }

  /// 앱 종료 전 남은 항목 개수 확인용(배지 표시 등에 쓸 수 있음).
  Future<int> pendingCount() async {
    final rows = await _db.select(_db.offlineActionQueue).get();
    return rows.length;
  }

  /// 체크리스트/웰니스 resolve 호출도 큐를 경유한다.
  /// clientEventId를 enqueue 시점에 발급·영속 저장하므로
  /// 네트워크 유실 후 재시도에서도 동일 ID가 재사용된다 (TR-03).
  ///
  /// [resolveType]: "checklist" 또는 "wellness"
  /// [itemId]: planPrepItemId 또는 wellnessActionId
  /// [status]: completionStatus 문자열 (pending/completed/dismissed)
  Future<bool> enqueueResolve({
    required String planId,
    required String resolveType,
    required String itemId,
    required String status,
  }) async {
    final clientEventId = _uuid.v4();

    final payload = {
      "resolveType": resolveType,
      "itemId": itemId,
      "status": status,
      "clientEventId": clientEventId,
    };

    await _db
        .into(_db.offlineActionQueue)
        .insert(
          OfflineActionQueueCompanion.insert(
            clientEventId: clientEventId,
            planId: planId,
            payloadJson: jsonEncode(payload),
            queuedAt: DateTime.now(),
          ),
        );

    return _flushResolve(planId, clientEventId, payload);
  }

  /// resolve 항목 즉시 전송 시도. 실패하면 큐에 남는다.
  Future<bool> _flushResolve(
    String planId,
    String clientEventId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final resolveType = payload["resolveType"] as String;
      final itemId = payload["itemId"] as String;
      final status = payload["status"] as String;
      final ceid = payload["clientEventId"] as String;

      if (resolveType == "checklist") {
        await _repo.resolveChecklistItem(
          planId,
          itemId,
          _parseChecklistStatus(status),
          clientEventId: ceid,
        );
      } else {
        await _repo.resolveWellnessAction(
          planId,
          itemId,
          _parseWellnessStatus(status),
          clientEventId: ceid,
        );
      }

      // 성공 → 큐에서 삭제
      await (_db.delete(
        _db.offlineActionQueue,
      )..where((t) => t.clientEventId.equals(clientEventId))).go();
      return true;
    } catch (_) {
      return false;
    }
  }

  ChecklistCompletionStatus _parseChecklistStatus(String s) {
    return s == "completed"
        ? ChecklistCompletionStatus.completed
        : ChecklistCompletionStatus.pending;
  }

  WellnessActionCompletionStatus _parseWellnessStatus(String s) {
    switch (s) {
      case "completed":
        return WellnessActionCompletionStatus.completed;
      case "dismissed":
        return WellnessActionCompletionStatus.dismissed;
      default:
        return WellnessActionCompletionStatus.proposed;
    }
  }
}
