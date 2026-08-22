import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:geofencing_api/geofencing_api.dart";
import "package:geolocator/geolocator.dart";
import "package:uuid/uuid.dart";
import "../models/action_log.dart";
import "../models/event.dart";
import "../models/plan.dart";
import "../providers/offline_queue_providers.dart";
import "../repository/providers.dart";

/// TR-08. 지오펜스는 활성 계획 1건 · 리전 2개(출발지 EXIT, 목적지 ENTER)로
/// 제한한다. iOS는 앱당 20개 리전 한도가 있고 초과분은 오류 없이 조용히
/// 무시되므로, 여러 일정을 동시에 등록하지 않는다(§9.1).
///
/// 서버는 지오펜스를 실행하지 않는다 — 판정 결과(종류·시각·신뢰도)만
/// 행동 API로 받는다(§9.2). 좌표는 절대 전송하지 않는다(절대 원칙 8).
class GeofenceManager {
  GeofenceManager(this._ref);

  final Ref _ref;
  final _uuid = const Uuid();
  bool _listenerRegistered = false;

  String? _activePlanId;
  String? _activeEventId;
  DateTime? _expectedArrival;
  final Map<String, DateTime> _lastStatusChangeAt = {};

  static const _exitRegionId = "active-plan-origin-exit";
  static const _enterRegionId = "active-plan-dest-enter";

  static const _originRadiusM = 150.0;
  // 목적지 유형(지상/지하)을 판별할 데이터가 클라이언트에 없어 D7의
  // 기본값(150m)을 쓴다. 유형 판별 데이터가 API에 추가되면 100/200m로
  // 세분화한다.
  static const _destRadiusM = 150.0;
  static const _dwellMs = 90000; // §9.2 "체류 90초 검증"

  static const _closedStatuses = {
    EventLifecycleStatus.closed,
    EventLifecycleStatus.cancelled,
    EventLifecycleStatus.skipped,
  };

  /// 계획이 바뀔 때마다(다음 일정 전환, 리비전 갱신 등) 호출한다.
  /// 활성 창(준비 시작 30분 전) 진입 여부를 스스로 판단해 등록/해제한다.
  Future<void> syncActivePlan(Event event, Plan plan) async {
    if (kIsWeb) return;
    _ensureListener();

    final now = DateTime.now();
    final withinActiveWindow = now.isAfter(
      plan.prepStartAt.subtract(const Duration(minutes: 30)),
    );
    final isActive =
        withinActiveWindow && !_closedStatuses.contains(plan.eventStatus);

    if (!isActive) {
      await clear();
      return;
    }
    if (_activePlanId == plan.planId) return; // 이미 이 계획으로 등록됨
    if (event.destinationLat == null || event.destinationLng == null) return;

    await clear();

    final origin = await _resolveOrigin();
    if (origin == null) {
      debugPrint("[geofence] 출발지 좌표를 확인하지 못해 등록을 건너뜀");
      return;
    }

    try {
      Geofencing.instance.addRegion(
        GeofenceRegion.circular(
          id: _exitRegionId,
          center: LatLng(origin.$1, origin.$2),
          radius: _originRadiusM,
        ),
      );
      Geofencing.instance.addRegion(
        GeofenceRegion.circular(
          id: _enterRegionId,
          center: LatLng(event.destinationLat!, event.destinationLng!),
          radius: _destRadiusM,
          loiteringDelay: _dwellMs,
        ),
      );
      if (!Geofencing.instance.isRunningService) {
        await Geofencing.instance.start();
      }
      _activePlanId = plan.planId;
      _activeEventId = event.eventId;
      _expectedArrival = plan.targetArriveAt;
    } catch (e) {
      // 리전 등록 실패(권한 거부, iOS 한도 등)는 사용자에게 노출하지
      // 않는다 — 홈의 수동 출발/도착 버튼이 대체 경로다(§9.3).
      debugPrint("[geofence] 리전 등록 실패: $e");
    }
  }

  /// 출발지 place가 등록돼 있으면 그 좌표를, 없으면 현재 GPS 위치를 쓴다.
  /// Event/Plan 응답에 출발지 좌표 필드 자체가 없어 API 확인이 필요한
  /// 부분이다 — 우선 이렇게 폴백한다.
  Future<(double, double)?> _resolveOrigin() async {
    try {
      final places = await _ref.read(ensomRepositoryProvider).fetchPlaces();
      final primary = places.isEmpty ? null : places.first;
      if (primary != null) return (primary.lat, primary.lng);
    } catch (_) {
      // fetchPlaces 미구현(UnimplementedError) 등 — GPS로 폴백
    }
    try {
      final position = await Geolocator.getCurrentPosition();
      return (position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  void _ensureListener() {
    if (_listenerRegistered) return;
    Geofencing.instance.addGeofenceStatusChangedListener(_onStatusChanged);
    _listenerRegistered = true;
  }

  Future<void> _onStatusChanged(
    GeofenceRegion region,
    GeofenceStatus status,
    Location location,
  ) async {
    final planId = _activePlanId;
    final eventId = _activeEventId;
    if (planId == null || eventId == null) return;

    final now = DateTime.now();
    final lastChange = _lastStatusChangeAt[region.id];
    final isFlicker =
        lastChange != null &&
        now.difference(lastChange) < const Duration(seconds: 60);
    _lastStatusChangeAt[region.id] = now;

    if (region.id == _exitRegionId && status == GeofenceStatus.exit) {
      await _ref
          .read(offlineActionQueueServiceProvider)
          .enqueue(
            planId: planId,
            actionType: ActionType.departed,
            actionSource: ActionSource.geo,
            confidence: isFlicker ? 0.4 : 0.7,
          );
      Geofencing.instance.removeRegionById(_exitRegionId);
      return;
    }

    if (region.id == _enterRegionId && status == GeofenceStatus.dwell) {
      // confidence 계산식 (TRD §9.2 D7)
      var confidence = 0.5 + 0.20; // 체류 조건은 dwell 상태 자체로 이미 충족
      if (location.accuracy < 50) confidence += 0.15;
      final expected = _expectedArrival;
      if (expected != null &&
          now.difference(expected).abs() <= const Duration(minutes: 20)) {
        confidence += 0.15;
      }
      if (isFlicker) confidence -= 0.30;
      confidence = confidence.clamp(0.0, 1.0);

      // ≥0.6만 자동 확정. 그 미만은 홈의 무신호 확인(§9.2)에 맡기고
      // 여기서는 아무 것도 보내지 않는다 — 잘못된 자동 확정보다
      // 사용자 확인이 안전하다.
      if (confidence >= 0.6) {
        try {
          await _ref
              .read(ensomRepositoryProvider)
              .reportArrival(
                eventId,
                planId,
                clientEventId: _uuid.v4(),
                source: ActionSource.geo,
                confidence: confidence,
              );
        } catch (e) {
          debugPrint("[geofence] 도착 보고 실패(백엔드 확인 필요): $e");
        }
      }
      await clear();
    }
  }

  Future<void> clear() async {
    if (!kIsWeb) {
      Geofencing.instance.removeRegionById(_exitRegionId);
      Geofencing.instance.removeRegionById(_enterRegionId);
    }
    _activePlanId = null;
    _activeEventId = null;
    _expectedArrival = null;
  }
}
