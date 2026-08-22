import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:geolocator/geolocator.dart";
import "package:go_router/go_router.dart";
import "package:hive_ce_flutter/hive_ce_flutter.dart";
import "package:uuid/uuid.dart";
import "../../local/place_cache_entry.dart";
import "../../models/place.dart";
import "../../providers/auth_providers.dart";
import "../../providers/map_providers.dart";
import "../../repository/providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_chip.dart";
import "../../widgets/ensom/ensom_pill_button.dart";

/// "직접 입력" 라벨은 세 곳(옵션 목록·필드 노출 가드·저장 분기)에서 쓰이므로
/// 상수로 둔다. 문구만 바꿔도 컴파일 에러 없이 커스텀 입력이 깨지던 것을 방지.
const _customLabel = "직접 입력";

const _labelOptions = ["집", "학교", "회사", _customLabel];

/// 커스텀 장소 이름 최대 길이 — 긴 이름이 행을 무한정 늘리지 않도록 제한.
const _maxCustomLabelLength = 20;

/// 라벨 → USER_PLACE.place_type 매핑. 스키마에 school 값이 없어
/// "학교"/"직접 입력"은 other로 잠정 처리한다(Place 모델 주석 참조).
String _placeTypeForLabel(String label) {
  switch (label) {
    case "집":
      return "home";
    case "회사":
      return "work";
    default:
      return "other";
  }
}

class PlaceRegistrationScreen extends ConsumerStatefulWidget {
  const PlaceRegistrationScreen({super.key, this.isOnboarding = false});

  /// 온보딩 흐름에서 호출되면 true — "완료/나중에" 버튼이 표시되고
  /// 완료 시 캘린더 연동 프라이밍으로 이동한다.
  final bool isOnboarding;

  @override
  ConsumerState<PlaceRegistrationScreen> createState() =>
      _PlaceRegistrationScreenState();
}

class _PlaceRegistrationScreenState
    extends ConsumerState<PlaceRegistrationScreen> {
  String selectedLabel = _labelOptions.first;
  final customLabelController = TextEditingController();
  double? lat;
  double? lng;
  String? resolvedAddress;
  bool locating = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    // 커스텀 라벨 입력에 따라 등록 버튼 활성/비활성이 즉시 반영되도록 한다.
    customLabelController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    customLabelController.dispose();
    super.dispose();
  }

  Box<PlaceCacheEntry> get _placeBox =>
      Hive.box<PlaceCacheEntry>("place_cache");

  /// build마다 새 BoxListenable이 생기지 않도록 한 번만 캐시한다. 슬라이더
  /// 드래그 중 잦은 setState에도 리스너가 반복 해제/재등록되지 않는다.
  late final ValueListenable<Box<PlaceCacheEntry>> _placeListenable = _placeBox
      .listenable();

  /// "직접 입력"을 골랐다면 이름이 채워져 있어야 등록 가능하다.
  bool get _customLabelReady =>
      selectedLabel != _customLabel ||
      customLabelController.text.trim().isNotEmpty;

  /// 등록하기 버튼 활성 조건: 위치가 선택됐고, 커스텀 이름 요건을 만족하며,
  /// 저장 중이 아닐 때.
  bool get _canRegister =>
      lat != null && lng != null && _customLabelReady && !saving;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _useCurrentLocation() async {
    setState(() => locating = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      // 좌표 → 주소 역지오코딩. BE POST /places가 address를 필수로 받으므로
      // 여기서 사람이 읽는 주소를 확보해 둔다. 키가 없거나 실패하면 null이며
      // 저장 시 좌표 문자열로 폴백한다(address는 not null이라 빈 값 불가).
      String? address;
      try {
        final search = ref.read(kakaoLocalSearchServiceProvider);
        address = await search.coord2address(
          position.latitude,
          position.longitude,
        );
      } catch (_) {
        address = null; // 역지오코딩 실패는 등록을 막지 않는다
      }
      if (!mounted) return;
      setState(() {
        lat = position.latitude;
        lng = position.longitude;
        resolvedAddress = address;
      });
    } catch (e) {
      // geofencing_api와 geolocator가 권한을 공유하지 않는 경우(또는
      // 그 자체가 권한이 미수락된 경우) 대비
      _showError("현재 위치를 가져오지 못했어요. 위치 권한을 확인해주세요.");
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> _register() async {
    if (lat == null || lng == null) return;
    final label = selectedLabel == _customLabel
        ? customLabelController.text.trim()
        : selectedLabel;
    if (label.isEmpty) {
      _showError("장소 이름을 입력해주세요.");
      return;
    }

    setState(() => saving = true);

    try {
      final repo = ref.read(ensomRepositoryProvider);
      final placeId = const Uuid().v4();
      final placeType = _placeTypeForLabel(label);
      // BE POST /places는 address 필수(@NotBlank, DB not null). 역지오코딩으로
      // 얻은 주소를 쓰고, 실패했으면 좌표가 아닌 상수 문자열로 폴백한다.
      //
      // 폴백에 좌표를 넣지 않는 이유: USER_PLACE.lat/lng는 앱 레벨 AES-GCM으로
      // 암호화 저장하는데(ERD USER_PLACE, PRD §13, TRD §14.3) address는 평문
      // text 컬럼이다. 여기에 좌표를 쓰면 암호화를 우회해 위치가 평문으로 남는다.
      // 카카오 REST 키 미주입 빌드에서는 모든 등록이 이 폴백을 타므로 특히 중요.
      final address = (resolvedAddress != null && resolvedAddress!.isNotEmpty)
          ? resolvedAddress!
          : "주소 미확인";
      final place = Place(
        placeId: placeId,
        placeType: placeType,
        placeName: label,
        address: address,
        lat: lat!,
        lng: lng!,
      );

      // 1. 서버에 등록 (mock)
      await repo.registerPlace(place);

      // 2. 로컬 캐시에 저장
      await _placeBox.put(
        placeId,
        PlaceCacheEntry(
          userId: "current-user", // 실제 로그인 붙으면 provider에서 가져오도록 교체
          placeId: placeId,
          placeName: label,
          placeType: placeType,
          lat: lat!,
          lng: lng!,
        ),
      );

      // 지오펜스는 여기서 등록하지 않는다. TR-08("활성 계획 1건·리전
      // 2개")에 따라 GeofenceManager(lib/services/geofence_manager.dart)가
      // 활성 계획의 출발지·목적지에 대해서만 등록하는 유일한 주체다.
      // 여기서 등록한 장소는 "자주 가는 장소" 목록(USER_PLACE)일 뿐이다.

      if (!mounted) return;
      setState(() {
        lat = null;
        lng = null;
        resolvedAddress = null;
        customLabelController.clear();
      });
    } catch (e) {
      _showError("장소 등록에 실패했어요. 다시 시도해주세요.");
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _confirmRemove(PlaceCacheEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("장소 삭제"),
        content: Text("'${entry.placeName}'을(를) 삭제할까요? 되돌릴 수 없어요."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              "삭제",
              style: TextStyle(color: EnsomColors.caution),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _remove(entry);
  }

  Future<void> _remove(PlaceCacheEntry entry) async {
    try {
      final repo = ref.read(ensomRepositoryProvider);
      await repo.deletePlace(entry.placeId);
      await _placeBox.delete(entry.placeId);
      if (mounted) setState(() {});
    } catch (e) {
      _showError("장소 삭제에 실패했어요. 다시 시도해주세요.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: AppBar(
        backgroundColor: EnsomColors.canvas,
        surfaceTintColor: EnsomColors.canvas,
        elevation: 0,
        title: Text(
          widget.isOnboarding ? "주요 장소 설정" : "등록 장소 관리",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: EnsomColors.ink,
          ),
        ),
        actions: [
          if (widget.isOnboarding)
            TextButton(
              onPressed: () async {
                // §4.1 주요 장소 다음은 캘린더 프라이밍이다.
                await ref
                    .read(authNotifierProvider.notifier)
                    .advanceOnboarding("calendar");
                if (context.mounted) {
                  context.go("/onboarding/priming/calendar");
                }
              },
              child: const Text(
                "완료",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: EnsomColors.surface1,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: EnsomColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "새 장소 등록",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.2,
                    color: EnsomColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 8,
                  children: [
                    for (final label in _labelOptions)
                      EnsomChip(
                        label: label,
                        selected: selectedLabel == label,
                        onTap: () => setState(() => selectedLabel = label),
                      ),
                  ],
                ),
                if (selectedLabel == _customLabel) ...[
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: EnsomColors.surface1,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: EnsomColors.hairline,
                          width: 1.4,
                        ),
                      ),
                      child: TextField(
                        controller: customLabelController,
                        textAlignVertical: TextAlignVertical.center,
                        maxLength: _maxCustomLabelLength,
                        style: const TextStyle(
                          fontSize: 13,
                          color: EnsomColors.ink,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "장소 이름",
                          isCollapsed: true,
                          counterText: "",
                          hintStyle: TextStyle(color: EnsomColors.inkFaint),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (lat != null && lng != null) ...[
                  if (resolvedAddress != null &&
                      resolvedAddress!.isNotEmpty) ...[
                    Text(
                      resolvedAddress!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: EnsomColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    "선택된 위치: ${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}",
                    style: const TextStyle(
                      fontSize: 11,
                      color: EnsomColors.inkFaint,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                EnsomPillButton(
                  label: locating ? "위치 확인 중..." : "현재 위치 사용",
                  variant: EnsomPillVariant.secondary,
                  onPressed: locating ? null : _useCurrentLocation,
                ),
                const SizedBox(height: 8),
                EnsomPillButton(
                  label: saving ? "등록 중..." : "등록하기",
                  onPressed: _canRegister ? _register : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            "등록된 장소",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -.2,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<Box<PlaceCacheEntry>>(
            valueListenable: _placeListenable,
            builder: (context, box, _) {
              final entries = box.values.toList();
              if (entries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    "아직 등록된 장소가 없어요.",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: EnsomColors.inkFaint,
                    ),
                  ),
                );
              }
              return Column(
                children: entries
                    .map(
                      (e) => _PlaceRow(
                        entry: e,
                        onDelete: () => _confirmRemove(e),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.entry, required this.onDelete});

  final PlaceCacheEntry entry;
  final VoidCallback onDelete;

  String _placeTypeLabel(String placeType) {
    switch (placeType) {
      case "home":
        return "집";
      case "work":
        return "직장";
      default:
        return "기타";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: EnsomColors.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EnsomColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: EnsomColors.surface2,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.place_outlined,
              size: 16,
              color: EnsomColors.inkMuted,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.placeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.2,
                    color: EnsomColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _placeTypeLabel(entry.placeType),
                  style: const TextStyle(
                    fontSize: 11,
                    color: EnsomColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          // 시각적 원은 30dp로 두되 터치 타깃은 48dp를 보장한다(오탭 방지).
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onDelete,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: EnsomColors.inkFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
