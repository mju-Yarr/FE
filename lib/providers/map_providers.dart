import "dart:convert";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_riverpod/legacy.dart";
import "package:hive_ce_flutter/hive_ce_flutter.dart";
import "../core/app_config.dart";
import "../models/bookmark.dart";
import "../models/event.dart";
import "../models/plan.dart";
import "../network/kakao_local_search_service.dart";
import "../repository/providers.dart";

final kakaoLocalSearchServiceProvider = Provider<KakaoLocalSearchService>((
  ref,
) {
  return KakaoLocalSearchService(restApiKey: kKakaoRestApiKey);
});

/// S-30 북마크 목록. 폴더 필터는 서버가 아니라 화면에서 건다 — 세그먼트를
/// 바꿀 때마다 재조회하면 목록이 깜빡인다.
final bookmarksProvider = FutureProvider.autoDispose<List<Bookmark>>((
  ref,
) async {
  return ref.watch(ensomRepositoryProvider).fetchBookmarks();
});

/// S-08 최근 목적지 · S-32 "최근" 탭.
final recentDestinationsProvider =
    FutureProvider.autoDispose<List<RecentDestination>>((ref) async {
      return ref.watch(ensomRepositoryProvider).fetchRecentDestinations();
    });

/// 지도 화면에서 만든 "저장 대기" 일정 초안. 목적지·경로가 정해지면
/// EventFormScreen의 지도 프리필 모드로 넘어가기 전에 여기 담아 둔다.
/// 화면 두 개를 오가는 흐름이라 URL 쿼리보다 provider로 넘기는 편이
/// 기존 컨벤션(planControllerProvider 등)과 더 맞는다.
class MapDraftEvent {
  const MapDraftEvent({
    this.originLat,
    this.originLng,
    this.originPlaceId,
    required this.destName,
    required this.destLat,
    required this.destLng,
    required this.selectedRoute,
    required this.anchorMode,
    required this.at,
    required this.createdAt,
    this.label,
    this.calendarSourceId,
  });

  static const routeOptionTtl = Duration(minutes: 30);

  final double? originLat;
  final double? originLng;
  final String? originPlaceId;
  final String destName;
  final double destLat;
  final double destLng;
  final RouteOption selectedRoute;
  final EventAnchor anchorMode;
  final DateTime at;
  final DateTime createdAt;

  /// S-45 간단 저장 시트에서 사용자가 입력하다 만 일정 이름.
  /// "자세히 편집"으로 넘어갈 때 입력값을 잃지 않게 프리필한다.
  final String? label;

  /// S-45에서 고른 저장 대상 캘린더. 자세히 편집으로 넘어가도 유지한다
  /// (§13 "S-45 프리필 — 다시 입력받지 않는다").
  final String? calendarSourceId;

  bool isExpiredAt(DateTime now) =>
      !now.isBefore(createdAt.add(routeOptionTtl));

  Map<String, dynamic> toJson() => {
    "originLat": originLat,
    "originLng": originLng,
    "originPlaceId": originPlaceId,
    "destName": destName,
    "destLat": destLat,
    "destLng": destLng,
    "selectedRoute": selectedRoute.toJson(),
    "anchorMode": anchorMode.name,
    "at": at.toIso8601String(),
    "createdAt": createdAt.toIso8601String(),
    "label": label,
    "calendarSourceId": calendarSourceId,
  };

  factory MapDraftEvent.fromJson(Map<String, dynamic> json) => MapDraftEvent(
    originLat: (json["originLat"] as num?)?.toDouble(),
    originLng: (json["originLng"] as num?)?.toDouble(),
    originPlaceId: json["originPlaceId"] as String?,
    destName: json["destName"] as String,
    destLat: (json["destLat"] as num).toDouble(),
    destLng: (json["destLng"] as num).toDouble(),
    selectedRoute: RouteOption.fromJson(
      json["selectedRoute"] as Map<String, dynamic>,
    ),
    anchorMode: EventAnchor.values.firstWhere(
      (e) => e.name == json["anchorMode"],
      orElse: () => EventAnchor.arriveBy,
    ),
    at: DateTime.parse(json["at"] as String),
    calendarSourceId: json["calendarSourceId"] as String?,
    // PR #57 이전 형식은 생성 시각이 없어 안전하게 만료 처리한다.
    createdAt:
        DateTime.tryParse(json["createdAt"] as String? ?? "") ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    label: json["label"] as String?,
  );
}

/// 지도 → 일정 폼 draft를 Hive에 영속화한다.
/// 복원이 끝나기 전 mutation이 들어오면 복원 완료 뒤 순서대로 적용해
/// 오래된 디스크 값이 새 메모리 상태를 덮어쓰지 못하게 한다.
class MapDraftEventNotifier extends StateNotifier<AsyncValue<MapDraftEvent?>> {
  MapDraftEventNotifier({DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const AsyncValue.loading()) {
    _restoreFuture = _restore();
  }

  static const _boxName = "map_draft";
  static const _key = "current";

  final DateTime Function() _now;
  late final Future<void> _restoreFuture;

  Future<void> _restore() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final raw = box.get(_key);
      if (raw == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final draft = MapDraftEvent.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (draft.isExpiredAt(_now())) {
        // 만료된 routeOptionId는 디스크에서 제거하되, 현재 실행 중에는
        // 목적지 정보를 유지해 EventFormScreen이 즉시 재검색을 안내한다.
        await box.delete(_key);
        state = AsyncValue.data(draft);
        return;
      }
      state = AsyncValue.data(draft);
    } catch (_) {
      // 손상된/읽을 수 없는 draft 때문에 앱 진입을 막지 않는다.
      state = const AsyncValue.data(null);
    }
  }

  Future<void> set(MapDraftEvent? draft) async {
    await _restoreFuture;
    state = AsyncValue.data(draft);
    try {
      final box = await Hive.openBox<String>(_boxName);
      if (draft == null) {
        await box.delete(_key);
      } else {
        await box.put(_key, jsonEncode(draft.toJson()));
      }
    } catch (_) {
      // 영속화 실패해도 현재 세션의 in-memory state는 유지한다.
    }
  }

  /// 일정 생성 완료, 로그아웃, 탈퇴 시 draft 소거.
  Future<void> clear() => set(null);
}

final mapDraftEventProvider =
    StateNotifierProvider<MapDraftEventNotifier, AsyncValue<MapDraftEvent?>>(
      (ref) => MapDraftEventNotifier(),
    );
