import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../network/kakao_local_search_service.dart";
import "../../providers/map_providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_pill_button.dart";
import "../../widgets/ensom/ensom_skeleton.dart";
import "../map/widgets/place_quick_pick_sheet.dart";

/// SRCH-01 장소 검색 전체화면
/// 호출: MAP-01, CAL-04, ONB-05, PRF-06
/// 결과 선택 시 KakaoSearchResult를 pop으로 반환.
///
/// 사용법:
/// ```dart
/// final result = await Navigator.push<KakaoSearchResult>(
///   context,
///   MaterialPageRoute(builder: (_) => const PlaceSearchScreen()),
/// );
/// ```
class PlaceSearchScreen extends ConsumerStatefulWidget {
  const PlaceSearchScreen({super.key});

  @override
  ConsumerState<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends ConsumerState<PlaceSearchScreen> {
  final _controller = TextEditingController();
  List<KakaoSearchResult> _results = [];
  bool _searching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _searching = true);
    final service = ref.read(kakaoLocalSearchServiceProvider);
    final results = await service.search(query);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
        _hasSearched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Material(
                    color: EnsomColors.surface2,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.arrow_back,
                          size: 15,
                          color: EnsomColors.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: EnsomColors.surface2,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            size: 15,
                            color: EnsomColors.inkFaint,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              onSubmitted: _search,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: EnsomColors.ink,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "장소를 검색하세요",
                                isCollapsed: true,
                                hintStyle: TextStyle(
                                  color: EnsomColors.inkFaint,
                                ),
                              ),
                            ),
                          ),
                          if (_controller.text.isNotEmpty)
                            InkWell(
                              onTap: () {
                                _controller.clear();
                                setState(() {
                                  _results = [];
                                  _hasSearched = false;
                                });
                              },
                              child: const Icon(
                                Icons.close,
                                size: 15,
                                color: EnsomColors.inkFaint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  /// §3 S-32는 S-08·S-10·S-38에서 재사용되는 공통 시트다. 고른 값을 이 화면의
  /// 반환 형식으로 바꿔 그대로 호출한 화면에 넘긴다.
  Future<void> _pickFromSaved() async {
    final picked = await showPlaceQuickPickSheet(context);
    if (picked == null || !mounted) return;
    Navigator.pop(
      context,
      KakaoSearchResult(
        name: picked.name,
        addressName: "",
        lat: picked.lat,
        lng: picked.lng,
      ),
    );
  }

  Widget _buildBody() {
    if (_searching) {
      // §11 로딩은 스켈레톤. 스피너는 스플래시 워드마크 링만.
      return const Padding(
        padding: EdgeInsets.fromLTRB(18, 4, 18, 16),
        child: EnsomSkeletonList(count: 4, itemHeight: 52),
      );
    }
    if (!_hasSearched) {
      // §11 빈 상태는 문구 + 다음 행동 CTA. 문구만 두고 끝내지 않는다.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "검색어를 입력하세요",
              style: TextStyle(fontSize: 12.5, color: EnsomColors.inkFaint),
            ),
            const SizedBox(height: 16),
            EnsomPillButton(
              label: "북마크·최근에서 고르기",
              variant: EnsomPillVariant.secondary,
              expand: false,
              onPressed: _pickFromSaved,
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          "검색 결과가 없어요",
          style: TextStyle(fontSize: 12.5, color: EnsomColors.inkFaint),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
      itemCount: _results.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: EnsomColors.hairline),
      itemBuilder: (context, index) {
        final item = _results[index];
        return InkWell(
          onTap: () => Navigator.pop(context, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: EnsomColors.surface2,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.place_outlined,
                    size: 15,
                    color: EnsomColors.inkMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: EnsomColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.addressName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: EnsomColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
