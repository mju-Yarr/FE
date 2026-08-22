import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../models/bookmark.dart";
import "../../network/api_client.dart";
import "../../providers/map_providers.dart";
import "../../repository/providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_chip.dart";
import "../../widgets/ensom/ensom_pill_button.dart";
import "../../widgets/ensom/ensom_skeleton.dart";
import "../../widgets/ensom/ensom_text_field.dart";
import "../../widgets/ensom/ensom_top_bar.dart";

/// S-30 북마크 목록 · S-31 편집.
///
/// 편집은 별도 화면 대신 같은 목록의 모드로 둔다 — 명세가 요구하는 동작은
/// "항목 체크 → 하단 액션 바(1개 이상일 때만) → 확인 다이얼로그 → 삭제 + 토스트,
/// 완료 → 목록으로"이고, 모드 전환으로 그대로 만족한다.
class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  static const _allFolders = "전체";

  String _selectedFolder = _allFolders;
  bool _editing = false;
  final _selected = <String>{};
  bool _busy = false;

  List<String> _folders(List<Bookmark> bookmarks) {
    final folders = <String>{_allFolders};
    for (final bookmark in bookmarks) {
      final folder = bookmark.folder;
      if (folder != null && folder.isNotEmpty) folders.add(folder);
    }
    return folders.toList();
  }

  List<Bookmark> _filtered(List<Bookmark> bookmarks) {
    if (_selectedFolder == _allFolders) return bookmarks;
    return bookmarks.where((b) => b.folder == _selectedFolder).toList();
  }

  void _toast(String message) {
    if (!mounted) return;
    // §9.3 토스트를 다시 부를 때 이전 것을 정리한다.
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(bookmarksProvider);
    } on ApiException catch (e) {
      _toast(switch (e.code) {
        "BOOKMARK_NOT_FOUND" => "이미 지워졌거나 찾을 수 없는 북마크가 있어요.",
        "NETWORK_ERROR" => "네트워크에 연결할 수 없어요.",
        _ => e.message,
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// §3 S-31 "삭제 → 확인 다이얼로그 → 삭제 + 토스트".
  Future<void> _deleteSelected() async {
    final count = _selected.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("북마크 $count개를 지울까요?"),
        content: const Text("지운 북마크는 되돌릴 수 없어요."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            // §9.2 빨강은 어디에도 쓰지 않는다. 삭제도 caution으로.
            style: TextButton.styleFrom(foregroundColor: EnsomColors.caution),
            child: const Text("삭제"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ids = _selected.toList();
    await _run(() async {
      // 하나라도 남의 것이면 서버가 전부 롤백하고 404를 준다 — 부분 삭제는 없다.
      await ref.read(ensomRepositoryProvider).bulkDeleteBookmarks(ids);
      _selected.clear();
      _toast("북마크 $count개를 지웠어요.");
    });
  }

  Future<void> _edit(Bookmark bookmark) async {
    final nameCtrl = TextEditingController(text: bookmark.placeName);
    final folderCtrl = TextEditingController(text: bookmark.folder ?? "");
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("북마크 편집"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EnsomTextField(label: "이름", controller: nameCtrl),
            const SizedBox(height: 12),
            EnsomTextField(label: "폴더 (선택)", controller: folderCtrl),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("저장"),
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final folder = folderCtrl.text.trim();
    nameCtrl.dispose();
    folderCtrl.dispose();
    if (saved != true) return;
    if (name.isEmpty) {
      _toast("이름을 입력해 주세요.");
      return;
    }
    await _run(() async {
      await ref
          .read(ensomRepositoryProvider)
          .patchBookmark(
            bookmark.bookmarkId,
            placeName: name,
            // 빈 문자열을 보내면 서버가 폴더를 지운다(BE blankToNull).
            folder: folder,
          );
      _toast("북마크를 수정했어요.");
    });
  }

  Future<void> _add() async {
    final nameCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final folderCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("북마크 추가"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EnsomTextField(label: "이름", controller: nameCtrl),
              const SizedBox(height: 12),
              EnsomTextField(
                label: "위도",
                controller: latCtrl,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              EnsomTextField(
                label: "경도",
                controller: lngCtrl,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              EnsomTextField(label: "폴더 (선택)", controller: folderCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("추가"),
          ),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final lat = double.tryParse(latCtrl.text.trim());
    final lng = double.tryParse(lngCtrl.text.trim());
    final folder = folderCtrl.text.trim();
    nameCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    folderCtrl.dispose();
    if (saved != true) return;
    if (name.isEmpty || lat == null || lng == null) {
      _toast("이름과 좌표를 정확히 입력해 주세요.");
      return;
    }
    await _run(() async {
      await ref
          .read(ensomRepositoryProvider)
          .createBookmark(
            placeName: name,
            lat: lat,
            lng: lng,
            folder: folder.isEmpty ? null : folder,
          );
      _toast("북마크를 추가했어요.");
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final hasBookmarks = (bookmarksAsync.value ?? const []).isNotEmpty;

    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: EnsomTopBar(
        title: _editing ? "북마크 편집" : "북마크",
        actions: [
          if (hasBookmarks)
            TextButton(
              onPressed: () => setState(() {
                _editing = !_editing;
                _selected.clear();
              }),
              child: Text(
                _editing ? "완료" : "편집",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: EnsomColors.ink,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _editing
          ? null
          : FloatingActionButton(
              backgroundColor: EnsomColors.cta,
              onPressed: _add,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: SafeArea(
        top: false,
        child: bookmarksAsync.when(
          // §11 로딩은 스켈레톤.
          loading: () => const Padding(
            padding: EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: EnsomSkeletonList(count: 4, itemHeight: 58),
          ),
          error: (err, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "북마크를 불러오지 못했어요.",
                    style: TextStyle(color: EnsomColors.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  EnsomPillButton(
                    label: "다시 시도",
                    expand: false,
                    onPressed: () => ref.invalidate(bookmarksProvider),
                  ),
                ],
              ),
            ),
          ),
          data: _buildList,
        ),
      ),
      // §3 S-31 하단 액션 바는 1개 이상 선택했을 때만 나온다.
      bottomNavigationBar: _editing && _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: EnsomPillButton(
                  label: "${_selected.length}개 삭제",
                  variant: EnsomPillVariant.secondary,
                  onPressed: _busy ? null : _deleteSelected,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildList(List<Bookmark> all) {
    final folders = _folders(all);
    final filtered = _filtered(all);

    return Column(
      children: [
        // §3 S-30 폴더 세그먼트 — 리스트 필터링. 이동 없음.
        if (folders.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: Row(
              children: folders
                  .map(
                    (folder) => Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: EnsomChip(
                        label: folder,
                        selected: folder == _selectedFolder,
                        onTap: () => setState(() => _selectedFolder = folder),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyBookmarks()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 90),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final bookmark = filtered[index];
                    return _BookmarkRow(
                      bookmark: bookmark,
                      editing: _editing,
                      selected: _selected.contains(bookmark.bookmarkId),
                      onToggleSelect: () => setState(() {
                        if (!_selected.remove(bookmark.bookmarkId)) {
                          _selected.add(bookmark.bookmarkId);
                        }
                      }),
                      onEdit: () => _edit(bookmark),
                      // §3 S-30 "북마크 행 탭 → 목적지 설정 → S-08R".
                      onOpen: () => context.push(
                        "/map?destLat=${bookmark.lat}&destLng=${bookmark.lng}"
                        "&destName=${Uri.encodeComponent(bookmark.placeName)}",
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// §11 빈 상태는 문구 + 다음 행동 CTA. 문구만 두고 끝내지 않는다.
class _EmptyBookmarks extends StatelessWidget {
  const _EmptyBookmarks();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "저장한 장소가 없어요.",
              style: TextStyle(color: EnsomColors.inkMuted),
            ),
            const SizedBox(height: 6),
            const Text(
              "자주 가는 곳을 저장하면 지도에서 바로 고를 수 있어요.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: EnsomColors.inkFaint),
            ),
            const SizedBox(height: 18),
            EnsomPillButton(
              label: "지도에서 찾기",
              expand: false,
              onPressed: () => context.go("/map"),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({
    required this.bookmark,
    required this.editing,
    required this.selected,
    required this.onToggleSelect,
    required this.onEdit,
    required this.onOpen,
  });

  final Bookmark bookmark;
  final bool editing;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final folder = bookmark.folder;
    return InkWell(
      onTap: editing ? onToggleSelect : onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: EnsomColors.surface1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? EnsomColors.cta : EnsomColors.hairline,
          ),
        ),
        child: Row(
          children: [
            if (editing)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: selected ? EnsomColors.cta : EnsomColors.hairline,
                ),
              )
            else
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(right: 12),
                decoration: const BoxDecoration(
                  color: EnsomColors.surface2,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bookmark_outline,
                  size: 15,
                  color: EnsomColors.inkMuted,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bookmark.placeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: EnsomColors.ink,
                    ),
                  ),
                  if (folder != null && folder.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      folder,
                      style: const TextStyle(
                        fontSize: 11,
                        color: EnsomColors.inkFaint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (editing)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 17),
                color: EnsomColors.inkMuted,
                tooltip: "이름·폴더 편집",
                onPressed: onEdit,
              ),
          ],
        ),
      ),
    );
  }
}
