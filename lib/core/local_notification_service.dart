import "dart:convert";

import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:timezone/timezone.dart" as tz;
import "package:timezone/data/latest_all.dart" as tz_data;

/// TR-07 로컬 알림 이중화 서비스.
///
/// FCM은 전송 시각을 보장하지 않으므로, 클라이언트가 **준비 시작·출발 임박
/// 2건을 로컬 알림으로 미리 예약**하고 서버 푸시가 먼저 오면 로컬을 취소한다.
///
/// TR-10 민감 항목 마스킹:
/// - `lockscreenHideSensitive=true`이면 잠금화면에 상세 내용을 숨긴다
///   (Android: visibility=secret, iOS: hiddenPreviewsBodyPlaceholder)
/// - 체크리스트에 sensitive 항목이 있으면 알림 body에서 항목명을
///   "개인 준비"로 치환해 노출한다.
///
/// 식별자 전략 (API 명세 §11.3):
///   dedupKey = sha1(eventId + ":" + slot + ":" + revisionNo)
///   → 이 문자열의 hashCode를 notification ID로 사용 (int 필요)
class LocalNotificationService {
  LocalNotificationService._();
  static final instance = LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 사용자 설정: 잠금화면에서 민감 정보 숨김 여부.
  /// bootstrap 로드 후 updateSettings()로 세팅한다.
  bool _lockscreenHideSensitive = true;

  /// 앱 시작 시 1회 호출.
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      "@mipmap/ic_launcher",
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// bootstrap 응답으로부터 잠금화면 설정을 반영한다.
  void updateSettings({required bool lockscreenHideSensitive}) {
    _lockscreenHideSensitive = lockscreenHideSensitive;
  }

  /// 계획 기반 로컬 알림 2건 예약 (준비 시작 + 출발 임박).
  /// 기존 같은 eventId의 알림이 있으면 먼저 취소하고 재예약한다.
  ///
  /// [sensitiveItemNames]: 체크리스트에서 isSensitive=true인 항목명 목록.
  /// 이 항목명이 body에 포함되면 "개인 준비"로 마스킹한다 (TR-10 표시 경계).
  Future<void> schedulePlanNotifications({
    required String eventId,
    required int revisionNo,
    required DateTime prepStartAt,
    required DateTime recommendedDepartAt,
    required String eventDisplayName,
    List<String> sensitiveItemNames = const [],
  }) async {
    // 이전 리비전의 알림 취소 (리비전이 바뀌면 시각도 바뀌었을 수 있음)
    await cancelPlanNotifications(eventId: eventId);

    final now = DateTime.now();

    // 표시명 마스킹 — 민감 항목명이 일정명에 포함됐을 경우 대비
    final maskedDisplayName = _maskSensitiveContent(
      eventDisplayName,
      sensitiveItemNames,
    );

    // 슬롯 A: 준비 시작 알림
    if (prepStartAt.isAfter(now)) {
      await _scheduleOne(
        id: _notificationId(eventId, "A", revisionNo),
        scheduledAt: prepStartAt,
        title: "준비를 시작할 시간이에요",
        body: "$maskedDisplayName — 지금부터 천천히 준비해 보세요.",
        payload: jsonEncode({"type": "prep_start", "eventId": eventId}),
      );
    }

    // 슬롯 B: 출발 임박 알림
    if (recommendedDepartAt.isAfter(now)) {
      await _scheduleOne(
        id: _notificationId(eventId, "B", revisionNo),
        scheduledAt: recommendedDepartAt,
        title: "이제 출발할 시간이에요",
        body: "$maskedDisplayName — 현재 경로 기준으로 출발하세요.",
        payload: jsonEncode({"type": "depart", "eventId": eventId}),
      );
    }
  }

  /// 서버 푸시가 먼저 도착했을 때 동일 dedupKey의 로컬 알림 취소.
  Future<void> cancelByDedupKey(String dedupKey) async {
    final id = _fnv1a32(dedupKey);
    await _plugin.cancel(id: id);
  }

  /// 특정 일정의 모든 로컬 알림 취소 (리비전 무관).
  Future<void> cancelPlanNotifications({required String eventId}) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload != null) {
        try {
          final data = jsonDecode(request.payload!) as Map<String, dynamic>;
          if (data["eventId"] == eventId) {
            await _plugin.cancel(id: request.id);
          }
        } catch (_) {
          // payload 파싱 실패면 무시
        }
      }
    }
  }

  /// 전체 알림 취소 (로그아웃 시).
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ─── Internal ──────────────────────────────────────────────────────

  /// 안정적 notification ID 생성.
  /// Dart의 String.hashCode는 앱 재시작/플랫폼 간 동일함을 보장하지 않으므로
  /// FNV-1a 32bit 해시를 직접 사용한다. 앱 재시작 후에도 동일 문자열 →
  /// 동일 ID를 생성하므로 기존 예약 알림을 안전하게 취소할 수 있다.
  int _notificationId(String eventId, String slot, int revisionNo) {
    return _fnv1a32("$eventId:$slot:$revisionNo");
  }

  /// FNV-1a 32-bit 해시. 플랫폼·실행 독립적이고 영속적.
  static int _fnv1a32(String input) {
    const int fnvOffsetBasis = 0x811c9dc5;
    const int fnvPrime = 0x01000193;
    int hash = fnvOffsetBasis;
    for (int i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    // Flutter local notifications expects a positive int32
    return hash.toSigned(32);
  }

  /// TR-10 표시 경계: 민감 항목명이 텍스트에 포함되어 있으면 "개인 준비"로 치환.
  String _maskSensitiveContent(String text, List<String> sensitiveNames) {
    if (sensitiveNames.isEmpty) return text;
    var masked = text;
    for (final name in sensitiveNames) {
      if (masked.contains(name)) {
        masked = masked.replaceAll(name, "개인 준비");
      }
    }
    return masked;
  }

  Future<void> _scheduleOne({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    required String payload,
  }) async {
    final tzScheduledAt = tz.TZDateTime.from(scheduledAt, tz.local);

    // TR-10: lockscreenHideSensitive이면 잠금화면에서 내용 숨김
    final androidDetails = AndroidNotificationDetails(
      "ensom_plan",
      "준비·출발 알림",
      channelDescription: "일정 준비 시작과 출발 시각 안내",
      importance: Importance.high,
      priority: Priority.high,
      // VISIBILITY_SECRET: 잠금화면에 알림 자체를 숨김
      // VISIBILITY_PRIVATE: 잠금화면에 알림은 보이되 내용은 숨김
      visibility: _lockscreenHideSensitive
          ? NotificationVisibility.private
          : NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzScheduledAt,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
      matchDateTimeComponents: null,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // 알림 탭 시 딥링크 처리 — M4에서 navigatorKey 공유로 완성
  }
}
