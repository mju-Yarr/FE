import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../models/bookmark.dart";
import "../../../network/api_client.dart";
import "../../../providers/map_providers.dart";
import "../../../repository/providers.dart";
import "../../../theme/ensom_colors.dart";
import "../../../widgets/ensom/ensom_chip.dart";
import "../../../widgets/ensom/ensom_skeleton.dart";

/// S-32에서 고른 장소. 시트는 화면을 스스로 전환하지 않고 이 값만 돌려준다
/// (§13 "S-32는 값을 반환하는 시트 — 호출한 화면이 결과를 받아 처리한다").
class PickedPlace {
  const PickedPlace({required this.name, required this.lat, required this.lng});

  final String name;
  final double lat;
  final double lng;
}

/// S-32 장소 빠른 선택 시트 — 북마크 · 최근 탭.
///
/// §3 S-32 "탭 → 리스트 교체. 이동 없음", "항목 선택 → 시트 닫고 호출한 화면에
/// 값 반환". 최근 목적지 행의 별은 북마크를 토글하며 시트를 닫지 않는다.
Future<PickedPlace?> showPlaceQuickPickSheet(BuildContext context) {
  return showModalBottomSheet<PickedPlace>(
    context: context,
    backgroundColor: EnsomColors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => const _PlaceQuickPickSheet(),
  );
}

enum _Tab { bookmarks, recent }

class _PlaceQuickPickSheet extends ConsumerStatefulWidget {
  const _PlaceQuickPickSheet();

  @override
  ConsumerState<_PlaceQuickPickSheet> createState() =>
      _PlaceQuickPickSheetState();
}

class _PlaceQuickPickSheetState extends ConsumerState<_PlaceQuickPickSheet> {
  _Tab _tab = _Tab.bookmarks;

  /// 토글 요청 중인 최근 목적지. 별 연타로 북마크가 두 번 만들어지지 않게 한다.
  final _pending = <String>{};

  /// 같은 좌표의 북마크를 찾는다. 서버가 recent.bookmarked를 판정하는 기준과
  /// 같지만, 해제하려면 bookmarkId가 필요해서 여기서 다시 찾는다.
  Bookmark? _matchingBookmark(List<Bookmark> bookmarks, RecentDestination r) {
    for (final bookmark in bookmarks) {
      if (_sameCoordinate(bookmark.lat, r.lat) &&
          _sameCoordinate(bookmark.lng, r.lng)) {
        return bookmark;
      }
    }
    return null;
  }

  // BE가 소수점 6자리로 저장하므로 그 정밀도에서 비교한다.
  bool _sameCoordinate(double a, double b) => (a - b).abs() < 0.0000005;

  Future<void> _toggleBookmark(RecentDestination recent) async {
    final id = recent.recentDestinationId;
    if (_pending.contains(id)) return;
    setState(() => _pending.add(id));
    try {
      final repo = ref.read(ensomRepositoryProvider);
      final existing = _matchingBookmark(
        ref.read(bookmarksProvider).value ?? const [],
        recent,
      );
      if (existing != null) {
        await repo.deleteBookmark(existing.bookmarkId);
      } else {
        await repo.createBookmark(
          placeName: recent.placeName,
          address: recent.address,
          lat: recent.lat,
          lng: recent.lng,
        );
      }
      ref.invalidate(bookmarksProvider);
      ref.invalidate(recentDestinationsProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _pending.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: EnsomColors.surfaceNeutral,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "장소 선택",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -.2,
                color: EnsomColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                EnsomChip(
                  label: "북마크",
                  selected: _tab == _Tab.bookmarks,
                  onTap: () => setState(() => _tab = _Tab.bookmarks),
                ),
                const SizedBox(width: 7),
                EnsomChip(
                  label: "최근",
                  selected: _tab == _Tab.recent,
                  onTap: () => setState(() => _tab = _Tab.recent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: _tab == _Tab.bookmarks
                  ? _buildBookmarks()
                  : _buildRecents(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarks() {
    return ref
        .watch(bookmarksProvider)
        .when(
          loading: () => const EnsomSkeletonList(count: 3, itemHeight: 46),
          error: (err, st) => const _SheetMessage("북마크를 불러오지 못했어요."),
          data: (bookmarks) => bookmarks.isEmpty
              ? const _SheetMessage("저장한 장소가 없어요.")
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: bookmarks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final bookmark = bookmarks[index];
                    return _PlaceRow(
                      icon: Icons.bookmark_outline,
                      name: bookmark.placeName,
                      subtitle: bookmark.folder,
                      onTap: () => Navigator.pop(
                        context,
                        PickedPlace(
                          name: bookmark.placeName,
                          lat: bookmark.lat,
                          lng: bookmark.lng,
                        ),
                      ),
                    );
                  },
                ),
        );
  }

  Widget _buildRecents() {
    final bookmarks = ref.watch(bookmarksProvider).value ?? const <Bookmark>[];
    return ref
        .watch(recentDestinationsProvider)
        .when(
          loading: () => const EnsomSkeletonList(count: 3, itemHeight: 46),
          error: (err, st) => const _SheetMessage("최근 목적지를 불러오지 못했어요."),
          data: (recents) => recents.isEmpty
              ? const _SheetMessage("최근에 간 곳이 아직 없어요.")
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: recents.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final recent = recents[index];
                    // 방금 토글한 결과가 목록 재조회보다 늦게 와도 별이 튀지
                    // 않도록 북마크 목록을 함께 본다.
                    final starred =
                        recent.bookmarked ||
                        _matchingBookmark(bookmarks, recent) != null;
                    return _PlaceRow(
                      icon: Icons.history,
                      name: recent.placeName,
                      subtitle: recent.address,
                      starred: starred,
                      // §3 S-08 "최근 목적지 행의 별 — 북마크 토글. 이동 없음".
                      onStar: _pending.contains(recent.recentDestinationId)
                          ? null
                          : () => _toggleBookmark(recent),
                      onTap: () => Navigator.pop(
                        context,
                        PickedPlace(
                          name: recent.placeName,
                          lat: recent.lat,
                          lng: recent.lng,
                        ),
                      ),
                    );
                  },
                ),
        );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 12.5, color: EnsomColors.inkFaint),
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.icon,
    required this.name,
    required this.onTap,
    this.subtitle,
    this.starred,
    this.onStar,
  });

  final IconData icon;
  final String name;
  final String? subtitle;
  final VoidCallback onTap;
  final bool? starred;
  final VoidCallback? onStar;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Material(
      color: EnsomColors.surface2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              Icon(icon, size: 17, color: EnsomColors.inkFaint),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: EnsomColors.ink,
                      ),
                    ),
                    if (sub != null && sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: EnsomColors.inkFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (starred != null)
                IconButton(
                  // §9.4 별 아이콘은 시각적으로 작아 히트 영역을 넓힌다.
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: Icon(
                    starred! ? Icons.star : Icons.star_border,
                    size: 18,
                    color: starred!
                        ? EnsomColors.limeInk
                        : EnsomColors.inkFaint,
                  ),
                  tooltip: starred! ? "북마크 해제" : "북마크에 저장",
                  onPressed: onStar,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
