import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:geolocator/geolocator.dart";
import "package:go_router/go_router.dart";
import "package:hive_ce_flutter/hive_ce_flutter.dart";
import "package:kakao_map_sdk/kakao_map_sdk.dart";
import "../../core/app_config.dart";
import "../../core/kakao_web_loader.dart";
import "../../local/place_cache_entry.dart";
import "../../models/event.dart";
import "../../models/plan.dart";
import "../../network/kakao_local_search_service.dart";
import "../../providers/map_providers.dart";
import "widgets/place_quick_pick_sheet.dart";
import "../../repository/providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_quick_save_sheet.dart";
import "../../widgets/permission_degraded_banner.dart";

/// MAP-01~04, CAL-05. 기본 지도 화면 -- 현재 위치 표시, 목적지 검색,
/// 경로 후보 조회, 캘린더 저장(일정 생성)까지가 이 화면의 범위다
/// (PRD §21.2 "지도는 기본 경로 기능만" -- 환경 레이어 등은 넣지 않는다).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({
    super.key,
    this.initialDestName,
    this.initialDestLat,
    this.initialDestLng,
  });

  final String? initialDestName;
  final double? initialDestLat;
  final double? initialDestLng;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  KakaoMapController? _controller;
  bool _locating = false;
  bool _retryingMap = false;
  String? _error;

  // 위치 권한 거부/실패 시 기본 위치 (서울시청). 지도 자체는 여전히
  // 정상 동작해야 한다 (PRD §23.2 "일부 실패해도 앱 중단 없음").
  static const _fallbackPosition = LatLng(37.5665, 126.9780);

  Position? _currentPosition;
  String? _destName;
  double? _destLat;
  double? _destLng;
  bool _searching = false;
  bool _routing = false;

  @override
  void initState() {
    super.initState();
    _applyInitialDestination();
  }

  /// 집·직장 등록 장소(§4.2 place_cache)에서 표시명이 일치하는 항목을 찾는다.
  PlaceCacheEntry? _placeByLabel(String name) {
    if (!Hive.isBoxOpen("place_cache")) return null;
    final box = Hive.box<PlaceCacheEntry>("place_cache");
    for (final entry in box.values) {
      if (entry.placeName == name) return entry;
    }
    return null;
  }

  void _selectDestination(String name, double lat, double lng) {
    setState(() {
      _destName = name;
      _destLat = lat;
      _destLng = lng;
    });
    _controller?.moveCamera(
      CameraUpdate.newCenterPosition(LatLng(lat, lng)),
      animation: const CameraAnimation(500),
    );
  }

  Future<void> _openBookmarkQuickPick() async {
    // S-32는 값을 반환하는 시트다. 화면 전환은 호출한 이쪽이 한다(§13).
    final picked = await showPlaceQuickPickSheet(context);
    if (picked == null || !mounted) return;
    _selectDestination(picked.name, picked.lat, picked.lng);
  }

  bool get _hasInitialDestination =>
      widget.initialDestLat != null && widget.initialDestLng != null;

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDestName == widget.initialDestName &&
        oldWidget.initialDestLat == widget.initialDestLat &&
        oldWidget.initialDestLng == widget.initialDestLng) {
      return;
    }
    setState(_applyInitialDestination);
    _moveToInitialDestination();
  }

  void _applyInitialDestination() {
    if (!_hasInitialDestination) return;
    _destName = widget.initialDestName?.trim().isNotEmpty == true
        ? widget.initialDestName
        : "선택한 위치";
    _destLat = widget.initialDestLat;
    _destLng = widget.initialDestLng;
  }

  Future<void> _moveToInitialDestination() async {
    if (!_hasInitialDestination) return;
    await _controller?.moveCamera(
      CameraUpdate.newCenterPosition(
        LatLng(widget.initialDestLat!, widget.initialDestLng!),
      ),
      animation: const CameraAnimation(500),
    );
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final position = await Geolocator.getCurrentPosition();
      _currentPosition = position;
      final location = LatLng(position.latitude, position.longitude);
      await _controller?.moveCamera(
        CameraUpdate.newCenterPosition(location),
        animation: const CameraAnimation(500),
      );
    } catch (e) {
      setState(() => _error = "현재 위치를 가져오지 못했어요. 위치 권한을 확인해주세요.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _retryWebMap() async {
    if (!kIsWeb || _retryingMap) return;
    setState(() => _retryingMap = true);
    final ready = await ensureKakaoWebSdk(kKakaoJavaScriptAppKey);
    if (!mounted) return;
    setState(() => _retryingMap = false);
    if (!ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("지도 연결에 실패했어요. 허용 도메인과 네트워크를 확인해 주세요.")),
      );
    }
  }

  Future<void> _onMapTapped(LatLng position) async {
    final search = ref.read(kakaoLocalSearchServiceProvider);
    if (search.isAvailable) return; // 검색 가능하면 탭-선택은 보조 수단일 뿐
    setState(() {
      _destName = "선택한 위치";
      _destLat = position.latitude;
      _destLng = position.longitude;
    });
  }

  Future<void> _openSearchSheet() async {
    final search = ref.read(kakaoLocalSearchServiceProvider);
    if (!search.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("검색을 쓸 수 없어요. 지도를 눌러 목적지를 선택해주세요.")),
      );
      return;
    }

    final controller = TextEditingController();
    List<KakaoSearchResult> results = const [];
    String? searchError;

    final selected = await showModalBottomSheet<KakaoSearchResult>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> runSearch(String query) async {
              setSheetState(() {
                _searching = true;
                searchError = null;
              });
              try {
                final found = await search.search(query);
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  results = found;
                  if (found.isEmpty) searchError = "검색 결과가 없어요.";
                });
              } on KakaoLocalSearchException catch (e) {
                if (!sheetContext.mounted) return;
                setSheetState(() => searchError = e.userMessage);
              } catch (_) {
                if (!sheetContext.mounted) return;
                setSheetState(
                  () => searchError = "장소 검색 중 오류가 발생했어요. 다시 시도해주세요.",
                );
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => _searching = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "목적지를 검색하세요",
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: runSearch,
                  ),
                  const SizedBox(height: 12),
                  if (_searching) const CircularProgressIndicator(),
                  if (!_searching && searchError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        searchError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: EnsomColors.inkMuted),
                      ),
                    ),
                  if (!_searching && searchError == null)
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final r = results[index];
                          return ListTile(
                            title: Text(r.name),
                            subtitle: Text(r.addressName),
                            onTap: () => Navigator.of(sheetContext).pop(r),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected == null) return;
    setState(() {
      _destName = selected.name;
      _destLat = selected.lat;
      _destLng = selected.lng;
    });
    await _controller?.moveCamera(
      CameraUpdate.newCenterPosition(LatLng(selected.lat, selected.lng)),
      animation: const CameraAnimation(500),
    );
  }

  Future<void> _searchRoutes() async {
    if (_destLat == null || _destLng == null || _destName == null) return;

    var origin = _currentPosition;
    if (origin == null) {
      try {
        origin = await Geolocator.getCurrentPosition();
      } catch (_) {
        // origin은 null로 유지 -- 아래에서 안내하고 중단한다.
      }
    }
    if (origin == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("출발 위치를 확인하지 못했어요. 위치 권한을 확인해주세요.")),
      );
      return;
    }

    final anchor = await _pickAnchor();
    if (anchor == null) return;

    setState(() => _routing = true);
    try {
      final repo = ref.read(ensomRepositoryProvider);
      final routes = await repo.fetchRouteSearch(
        originLat: origin.latitude,
        originLng: origin.longitude,
        destLat: _destLat!,
        destLng: _destLng!,
        destName: _destName!,
        anchorMode: anchor.$1,
        at: anchor.$2,
      );
      final routesFetchedAt = DateTime.now();
      if (!mounted) return;

      // 빈 결과 처리 — BE에 /routes/search가 없거나 경로를 찾지 못한 경우
      if (routes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("경로 검색을 사용할 수 없어요. 서버 준비 후 다시 시도해주세요.")),
        );
        return;
      }

      final selectedRoute = await _showRouteSheet(routes);
      if (selectedRoute == null) return;
      if (!mounted) return;

      final quickSave = await EnsomQuickSaveSheet.show(
        context,
        destName: _destName!,
        anchorMode: anchor.$1,
        at: anchor.$2,
        route: selectedRoute,
      );
      if (quickSave == null) return;

      if (quickSave.detailedEdit) {
        await ref
            .read(mapDraftEventProvider.notifier)
            .set(
              MapDraftEvent(
                originLat: origin.latitude,
                originLng: origin.longitude,
                destName: _destName!,
                destLat: _destLat!,
                destLng: _destLng!,
                selectedRoute: selectedRoute,
                anchorMode: anchor.$1,
                at: anchor.$2,
                createdAt: routesFetchedAt,
                label: quickSave.label,
                calendarSourceId: quickSave.calendarSourceId,
              ),
            );
        if (!mounted) return;
        context.push("/events/create-from-map");
        return;
      }

      final endsAt = anchor.$1 == EventAnchor.arriveBy
          ? anchor.$2
          : anchor.$2.add(const Duration(hours: 1));
      await ref
          .read(ensomRepositoryProvider)
          .createEvent(
            Event(
              eventId: "",
              displayLabel: quickSave.label!,
              displayName: quickSave.label!,
              startsAt: anchor.$1 == EventAnchor.arriveBy
                  ? anchor.$2.subtract(const Duration(hours: 1))
                  : anchor.$2,
              endsAt: endsAt,
              locationState: LocationState.requiredResolved,
              destinationName: _destName,
              destinationLat: _destLat,
              destinationLng: _destLng,
              anchor: anchor.$1,
              sourceType: EventSourceType.mapSearch,
            ),
            selectedRouteOptionId: selectedRoute.routeOptionId,
            writeToCalendarSourceId: quickSave.calendarSourceId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("일정으로 저장했어요.")));
      setState(() {
        _destName = null;
        _destLat = null;
        _destLng = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("경로를 찾지 못했어요. 다시 시도해주세요.")));
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  Future<(EventAnchor, DateTime)?> _pickAnchor() async {
    var anchorMode = EventAnchor.arriveBy;
    var at = DateTime.now().add(const Duration(hours: 1));

    return showModalBottomSheet<(EventAnchor, DateTime)>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<EventAnchor>(
                    segments: const [
                      ButtonSegment(
                        value: EventAnchor.arriveBy,
                        label: Text("도착 시각 기준"),
                      ),
                      ButtonSegment(
                        value: EventAnchor.departAt,
                        label: Text("출발 시각 기준"),
                      ),
                    ],
                    selected: {anchorMode},
                    onSelectionChanged: (s) =>
                        setSheetState(() => anchorMode = s.first),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text("시각"),
                    subtitle: Text(
                      "${at.month}/${at.day} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}",
                    ),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: sheetContext,
                        initialDate: at,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date == null) return;
                      if (!sheetContext.mounted) return;
                      final time = await showTimePicker(
                        context: sheetContext,
                        initialTime: TimeOfDay.fromDateTime(at),
                      );
                      if (time == null) return;
                      setSheetState(() {
                        at = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(sheetContext).pop((anchorMode, at)),
                    child: const Text("경로 검색"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _rankLabel(RouteType type) {
    switch (type) {
      case RouteType.fastest:
        return "가장 빠른 경로";
      case RouteType.leastWalk:
        return "도보가 적은 경로";
      case RouteType.leastTransfer:
        return "환승이 적은 경로";
    }
  }

  Future<RouteOption?> _showRouteSheet(List<RouteOption> routes) {
    return showModalBottomSheet<RouteOption>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          itemCount: routes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final route = routes[index];
            return Card(
              child: ListTile(
                title: Text(_rankLabel(route.routeType)),
                subtitle: Text(
                  "${route.totalMinutes}분 · 도보 ${route.walkMinutes}분 · 환승 ${route.transferCount}회",
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(sheetContext).pop(route),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(kakaoLocalSearchServiceProvider);
    final destSelected = _destLat != null && _destLng != null;
    final mapAvailable = kIsWeb
        ? isKakaoWebSdkReady
        : kKakaoNativeAppKey.isNotEmpty;

    // S-08 "검색 전" 화면 구성 원칙: 검색 바 우측에 아이콘을 두지 않고,
    // 북마크 전체 목록 진입구는 칩 줄 끝의 '전체보기' 하나뿐이다.
    final home = _placeByLabel("집");
    final work = _placeByLabel("회사");

    return Scaffold(
      body: Stack(
        children: [
          // kakao_map_sdk 1.2.6은 Web 플러그인을 제공한다. Web에서는
          // main.dart가 JavaScript SDK 로드를 완료한 경우에만 공통 KakaoMap을
          // 만들고, 키/도메인/네트워크 설정이 없으면 지도 영역만 저하한다.
          if (!mapAvailable)
            _WebMapPlaceholder(retrying: _retryingMap, onRetry: _retryWebMap)
          else
            KakaoMap(
              option: KakaoMapOption(
                position: destSelected
                    ? LatLng(_destLat!, _destLng!)
                    : _fallbackPosition,
                zoomLevel: 16,
                mapType: MapType.normal,
              ),
              onMapReady: (controller) {
                _controller = controller;
                if (_hasInitialDestination) {
                  _moveToInitialDestination();
                } else {
                  _moveToCurrentLocation();
                }
              },
              onMapClick: (point, position) => _onMapTapped(position),
            ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _openSearchSheet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: EnsomColors.inkMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _destName ??
                              (search.isAvailable
                                  ? "목적지를 검색하세요"
                                  : "지도를 눌러 목적지를 선택해주세요"),
                          style: TextStyle(
                            color: _destName != null
                                ? EnsomColors.ink
                                : EnsomColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 72,
            left: 16,
            right: 16,
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (home != null)
                  _MapChip(
                    label: "집",
                    onTap: () => _selectDestination("집", home.lat, home.lng),
                  ),
                if (work != null)
                  _MapChip(
                    label: "회사",
                    onTap: () => _selectDestination("회사", work.lat, work.lng),
                  ),
                // §3 S-08 칩 줄 — 집·직장 다음에 북마크 항목들이 온다.
                // 다 넣으면 줄이 길어져 앞쪽 몇 개만 칩으로 두고 나머지는
                // 빠른 선택 시트에서 고른다.
                for (final bookmark
                    in (ref.watch(bookmarksProvider).value ?? const []).take(4))
                  _MapChip(
                    label: bookmark.placeName,
                    icon: Icons.bookmark_outline,
                    onTap: () => _selectDestination(
                      bookmark.placeName,
                      bookmark.lat,
                      bookmark.lng,
                    ),
                  ),
                _MapChip(
                  label: "북마크",
                  icon: Icons.bookmark_outline,
                  onTap: _openBookmarkQuickPick,
                ),
                // §3 "북마크 전체 목록 진입구는 칩 줄 끝의 전체보기 하나뿐이다."
                _MapChip(
                  label: "전체보기",
                  onTap: () => context.push("/map/bookmarks"),
                ),
              ],
            ),
          ),
          if (_error != null)
            Positioned(
              top: 122,
              left: 16,
              right: 16,
              child: Material(
                color: EnsomColors.panel,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: EnsomColors.canvas,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: _error != null ? 186 : 122,
            left: 16,
            right: 16,
            child: const PermissionDegradedBanner(
              type: DegradedPermissionType.location,
            ),
          ),
          if (destSelected)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _destName!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      FilledButton(
                        onPressed: _routing ? null : _searchRoutes,
                        child: _routing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("경로 검색"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 우측 하단 확대·축소·현재 위치 3개만 (§3 S-08 "화면 구성").
          Positioned(
            right: 16,
            bottom: destSelected ? 96 : 24,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "zoomIn",
                  onPressed: () =>
                      _controller?.moveCamera(CameraUpdate.zoomIn()),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: "zoomOut",
                  onPressed: () =>
                      _controller?.moveCamera(CameraUpdate.zoomOut()),
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "myLocation",
                  onPressed: _locating ? null : _moveToCurrentLocation,
                  child: _locating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// §3 S-08 "장소 칩 줄" — 집·직장·북마크 항목들·전체보기, 가로 스크롤.
/// §9.3 칩 규격(12px/600, radius 12px)을 그대로 따른다.
class _MapChip extends StatelessWidget {
  const _MapChip({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Material(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: EnsomColors.ink),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: EnsomColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 지도 SDK 키가 없거나 Web script/도메인 인증에 실패했을 때의 저하 화면.
/// 검색·북마크·경로 저장은 가능한 범위에서 계속 동작한다.
class _WebMapPlaceholder extends StatelessWidget {
  const _WebMapPlaceholder({required this.retrying, required this.onRetry});

  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: EnsomColors.surface2,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.map_outlined,
                size: 44,
                color: EnsomColors.inkFaint,
              ),
              const SizedBox(height: 12),
              const Text(
                "지도를 불러오지 못했어요",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: EnsomColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "지도 키와 허용 도메인을 확인해 주세요.\n목적지 검색과 경로 저장은 계속 이용할 수 있어요.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: EnsomColors.inkFaint),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: retrying ? null : onRetry,
                child: Text(retrying ? "다시 연결하는 중..." : "지도 다시 연결"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
