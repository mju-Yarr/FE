import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../models/event.dart";
import "../../network/api_client.dart";
import "../../network/kakao_local_search_service.dart";
import "../../models/calendar_connection.dart";
import "../../providers/calendar_providers.dart";
import "../../providers/map_providers.dart";
import "../map/widgets/place_quick_pick_sheet.dart";
import "../../repository/providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_chip.dart";
import "../../widgets/ensom/ensom_date_picker_sheet.dart";
import "../../widgets/ensom/ensom_pill_button.dart";
import "../../widgets/ensom/ensom_time_picker_sheet.dart";
import "../../widgets/ensom/ensom_top_bar.dart";
import "../search/place_search_screen.dart";

@visibleForTesting
DateTime nextEventStartTime(DateTime now) {
  final candidate = now.add(const Duration(hours: 1));
  final roundedMinute = candidate.minute < 30 ? 30 : 0;
  return DateTime(
    candidate.year,
    candidate.month,
    candidate.day,
    roundedMinute == 0 ? candidate.hour + 1 : candidate.hour,
    roundedMinute,
  );
}

/// S-10 일정 생성 폼.
/// 캘린더의 빈 폼과 S-08R에서 넘어온 지도 프리필을 하나의 화면으로 처리한다.
///
/// ensom_onboarding_flow.html STEP 5("첫 일정을 만들어 볼까요?")의
/// 필드/값행(vrow)/칩 시각 언어를 반영한다. 전용 목업 파일은 없어서
/// 온보딩 흐름 안의 같은 폼 패턴을 재사용했다.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.fromMap = false});

  final bool fromMap;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _labelController = TextEditingController();
  DateTime _startsAt = nextEventStartTime(DateTime.now());
  LocationState _locationState = LocationState.undecided;
  bool _timeExpanded = false;
  bool _autoManageExcluded = false;

  /// §3 S-10 "저장할 캘린더 선택". 연동된 쓰기 가능 캘린더가 있을 때만 보인다.
  /// null이면 서버가 기본 기록 캘린더를 쓴다.
  String? _writeToCalendarSourceId;
  String? _destinationName;
  double? _destinationLat;
  double? _destinationLng;
  MapDraftEvent? _mapDraft;
  bool _saving = false;

  void _applyMapDraft(MapDraftEvent draft) {
    if (identical(_mapDraft, draft)) return;
    _mapDraft = draft;
    _startsAt = draft.anchorMode == EventAnchor.departAt
        ? draft.at
        : draft.at.subtract(const Duration(hours: 1));
    _locationState = LocationState.requiredResolved;
    // §13 "S-45 프리필 — 다시 입력받지 않는다". 시트에서 고른 캘린더를 잇는다.
    _writeToCalendarSourceId = draft.calendarSourceId;
    _destinationName = draft.destName;
    _destinationLat = draft.destLat;
    _destinationLng = draft.destLng;
    if (draft.label != null && draft.label!.isNotEmpty) {
      _labelController.text = draft.label!;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickDestination() async {
    final result = await Navigator.push<KakaoSearchResult>(
      context,
      MaterialPageRoute(builder: (_) => const PlaceSearchScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _destinationName = result.name;
        _destinationLat = result.lat;
        _destinationLng = result.lng;
      });
    }
  }

  /// S-32 공통 시트 재사용. 시트는 값만 돌려주고 화면 전환은 하지 않는다.
  Future<void> _pickSavedDestination() async {
    final picked = await showPlaceQuickPickSheet(context);
    if (picked == null || !mounted) return;
    setState(() {
      _destinationName = picked.name;
      _destinationLat = picked.lat;
      _destinationLng = picked.lng;
    });
  }

  void _setDateOffset(int days) {
    final today = DateTime.now();
    setState(() {
      _startsAt = DateTime(
        today.year,
        today.month,
        today.day + days,
        _startsAt.hour,
        _startsAt.minute,
      );
    });
  }

  void _adjustTime(int minutes) {
    setState(() => _startsAt = _startsAt.add(Duration(minutes: minutes)));
  }

  void _setSpecificTime(int hour, int minute) {
    setState(() {
      _startsAt = DateTime(
        _startsAt.year,
        _startsAt.month,
        _startsAt.day,
        hour,
        minute,
      );
    });
  }

  Future<void> _pickCustomDate() async {
    final date = await EnsomDatePickerSheet.show(context, initial: _startsAt);
    if (date == null || !mounted) return;

    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        _startsAt.hour,
        _startsAt.minute,
      );
    });
  }

  Future<void> _pickCustomTime() async {
    final time = await EnsomTimePickerSheet.show(
      context,
      initial: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _startsAt = DateTime(
        _startsAt.year,
        _startsAt.month,
        _startsAt.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<bool> _confirmClassificationIfNeeded() async {
    if (_locationState != LocationState.undecided) return true;

    final answer = await showModalBottomSheet<LocationState>(
      context: context,
      backgroundColor: EnsomColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "이 일정에 장소가 필요한가요?",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3,
                  color: EnsomColors.ink,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                "한 번 답하면 같은 일정에 다시 묻지 않아요.",
                style: TextStyle(fontSize: 12.5, color: EnsomColors.inkMuted),
              ),
              const SizedBox(height: 20),
              EnsomPillButton(
                label: "네, 장소가 있어요",
                onPressed: () =>
                    Navigator.pop(sheetContext, LocationState.requiredMissing),
              ),
              const SizedBox(height: 8),
              EnsomPillButton(
                label: "아니요, 온라인·재택이에요",
                variant: EnsomPillVariant.secondary,
                onPressed: () =>
                    Navigator.pop(sheetContext, LocationState.notRequired),
              ),
              EnsomPillButton(
                label: "잘 모르겠어요",
                variant: EnsomPillVariant.text,
                onPressed: () =>
                    Navigator.pop(sheetContext, LocationState.undecided),
              ),
            ],
          ),
        ),
      ),
    );

    if (answer == null) return false;
    setState(() => _locationState = answer);

    if (answer == LocationState.requiredMissing) {
      await _pickDestination();
      return _destinationName != null;
    }

    // `잘 모르겠어요`는 undecided를 그대로 전송해 미해결 상태를 보존한다.
    return true;
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    if (label.isEmpty || _saving) return;

    if (!await _confirmClassificationIfNeeded()) return;
    if (_locationState == LocationState.requiredMissing &&
        _destinationName == null) {
      await _pickDestination();
      if (_destinationName == null) return;
    }

    final draft = _mapDraft;
    if (draft != null && draft.isExpiredAt(DateTime.now())) {
      await ref.read(mapDraftEventProvider.notifier).clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("선택한 경로가 만료됐어요. 경로를 다시 검색해주세요.")),
      );
      context.go(
        Uri(
          path: "/map",
          queryParameters: {
            "destName": draft.destName,
            "destLat": draft.destLat.toString(),
            "destLng": draft.destLng.toString(),
          },
        ).toString(),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final endsAt = draft?.anchorMode == EventAnchor.arriveBy
          ? draft!.at
          : _startsAt.add(const Duration(hours: 1));
      final event = Event(
        eventId: "",
        displayLabel: label,
        displayName: label,
        startsAt: _startsAt,
        endsAt: endsAt,
        locationState:
            _locationState == LocationState.requiredMissing &&
                _destinationName != null
            ? LocationState.requiredResolved
            : _locationState,
        destinationName: _destinationName,
        destinationLat: _destinationLat,
        destinationLng: _destinationLng,
        anchor: draft?.anchorMode ?? EventAnchor.arriveBy,
        sourceType: draft == null
            ? EventSourceType.internal
            : EventSourceType.mapSearch,
        autoManageExcluded: _autoManageExcluded,
      );

      final created = await ref
          .read(ensomRepositoryProvider)
          .createEvent(
            event,
            originPlaceId: draft?.originPlaceId,
            selectedRouteOptionId: draft?.selectedRoute.routeOptionId,
            writeToCalendarSourceId: _writeToCalendarSourceId,
          );

      ref.invalidate(eventsInRangeProvider);
      ref.invalidate(pendingReviewsProvider);

      if (draft != null) {
        await ref.read(mapDraftEventProvider.notifier).clear();
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("일정을 저장했어요."),
          duration: Duration(seconds: 2),
        ),
      );
      context.pushReplacement("/events/${created.eventId}");
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stackTrace) {
      debugPrint("[event-create] 실패: $error\n$stackTrace");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("일정을 저장하지 못했어요. 다시 시도해주세요.")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildMapPrefill(MapDraftEvent draft) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: EnsomColors.lime,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            draft.destName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -.3,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "${draft.selectedRoute.totalMinutes}분 · 도보 ${draft.selectedRoute.walkMinutes}분 · 환승 ${draft.selectedRoute.transferCount}회",
            style: TextStyle(
              fontSize: 12,
              color: EnsomColors.ink.withValues(alpha: .72),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            draft.anchorMode == EventAnchor.arriveBy
                ? "도착 ${_formatDateTime(draft.at)}"
                : "출발 ${_formatDateTime(draft.at)}",
            style: TextStyle(
              fontSize: 12,
              color: EnsomColors.ink.withValues(alpha: .72),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            "지도에서 선택한 장소·시각·경로가 적용됐어요.",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: EnsomColors.limeInk,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    const weekdays = ["월", "화", "수", "목", "금", "토", "일"];
    final period = value.hour < 12 ? "오전" : "오후";
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, "0");
    return "${value.month}월 ${value.day}일 ${weekdays[value.weekday - 1]} · $period $hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fromMap) {
      final draftState = ref.watch(mapDraftEventProvider);
      if (draftState.isLoading) {
        return const _LoadingScaffold();
      }
      if (draftState.hasValue && draftState.value != null) {
        _applyMapDraft(draftState.value!);
      }
    }

    final draft = _mapDraft;
    if (widget.fromMap && draft != null && draft.isExpiredAt(DateTime.now())) {
      return Scaffold(
        backgroundColor: EnsomColors.canvas,
        appBar: const EnsomTopBar(title: "일정 만들기"),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "선택한 경로가 만료됐어요.",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                    color: EnsomColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${draft.destName} 경로를 다시 검색해주세요.",
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: EnsomColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 20),
                EnsomPillButton(
                  label: "경로 다시 검색",
                  expand: false,
                  onPressed: () async {
                    await ref.read(mapDraftEventProvider.notifier).clear();
                    if (!context.mounted) return;
                    context.go(
                      Uri(
                        path: "/map",
                        queryParameters: {
                          "destName": draft.destName,
                          "destLat": draft.destLat.toString(),
                          "destLng": draft.destLng.toString(),
                        },
                      ).toString(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (widget.fromMap && draft == null) {
      return const Scaffold(
        backgroundColor: EnsomColors.canvas,
        appBar: EnsomTopBar(title: "일정 만들기"),
        body: Center(
          child: Text(
            "선택한 경로 정보를 찾을 수 없어요.",
            style: TextStyle(color: EnsomColors.inkMuted),
          ),
        ),
      );
    }

    final canSave = !_saving && _labelController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: EnsomTopBar(
        title: "일정 만들기",
        actions: [
          TextButton(
            onPressed: canSave ? _save : null,
            child: Text(
              _saving ? "저장 중" : "저장",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                children: [
                  if (draft != null) ...[
                    _buildMapPrefill(draft),
                    const SizedBox(height: 18),
                  ],
                  TextField(
                    controller: _labelController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.3,
                      color: EnsomColors.ink,
                    ),
                    decoration: const InputDecoration(
                      hintText: "일정 제목",
                      hintStyle: TextStyle(
                        color: EnsomColors.inkFaint,
                        fontWeight: FontWeight.w700,
                      ),
                      contentPadding: EdgeInsets.fromLTRB(2, 14, 2, 12),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: EnsomColors.hairline),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: EnsomColors.cta),
                      ),
                    ),
                  ),
                  if (draft == null) ...[
                    const SizedBox(height: 8),
                    _EventTimeEditor(
                      startsAt: _startsAt,
                      expanded: _timeExpanded,
                      formattedValue: _formatDateTime(_startsAt),
                      onToggle: () =>
                          setState(() => _timeExpanded = !_timeExpanded),
                      onDateOffset: _setDateOffset,
                      onAdjustMinutes: _adjustTime,
                      onSpecificTime: _setSpecificTime,
                      onCustomDate: _pickCustomDate,
                      onCustomTime: _pickCustomTime,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "장소",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: EnsomColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 8,
                      children: [
                        EnsomChip(
                          label: "장소 필요",
                          selected:
                              _locationState == LocationState.requiredMissing,
                          onTap: () => setState(() {
                            _locationState = LocationState.requiredMissing;
                          }),
                        ),
                        EnsomChip(
                          label: "장소 불필요",
                          selected: _locationState == LocationState.notRequired,
                          onTap: () => setState(() {
                            _locationState = LocationState.notRequired;
                            _destinationName = null;
                            _destinationLat = null;
                            _destinationLng = null;
                          }),
                        ),
                        EnsomChip(
                          label: "미정",
                          selected: _locationState == LocationState.undecided,
                          onTap: () => setState(() {
                            _locationState = LocationState.undecided;
                            _destinationName = null;
                            _destinationLat = null;
                            _destinationLng = null;
                          }),
                        ),
                      ],
                    ),
                    if (_locationState == LocationState.requiredMissing) ...[
                      const SizedBox(height: 10),
                      _ValueRow(
                        value: _destinationName ?? "목적지 검색",
                        hint: _destinationName == null,
                        leading: Icons.place_outlined,
                        trailing: Icons.search,
                        onTap: _pickDestination,
                      ),
                      // §3 S-10 "목적지 필드 → [시트] S-32 또는 [푸시] S-38".
                      // 자주 가는 곳은 검색을 거치지 않고 바로 고른다.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _pickSavedDestination,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            foregroundColor: EnsomColors.inkMuted,
                            textStyle: const TextStyle(
                              fontSize: 11.5,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          child: const Text("북마크·최근에서 고르기"),
                        ),
                      ),
                    ],
                  ],
                  _CalendarTargetPicker(
                    selectedId: _writeToCalendarSourceId,
                    onSelected: (id) =>
                        setState(() => _writeToCalendarSourceId = id),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: EnsomColors.hairline),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "이 일정은 준비 알림에서 제외",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: EnsomColors.ink,
                            ),
                          ),
                        ),
                        Switch(
                          value: _autoManageExcluded,
                          activeTrackColor: EnsomColors.cta,
                          activeThumbColor: EnsomColors.lime,
                          onChanged: (value) =>
                              setState(() => _autoManageExcluded = value),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: const BoxDecoration(
                color: EnsomColors.surface1,
                border: Border(top: BorderSide(color: EnsomColors.hairline)),
              ),
              child: EnsomPillButton(
                label: _saving ? "저장 중..." : "저장",
                onPressed: canSave ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: EnsomTopBar(title: "일정 만들기"),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EventTimeEditor extends StatelessWidget {
  const _EventTimeEditor({
    required this.startsAt,
    required this.expanded,
    required this.formattedValue,
    required this.onToggle,
    required this.onDateOffset,
    required this.onAdjustMinutes,
    required this.onSpecificTime,
    required this.onCustomDate,
    required this.onCustomTime,
  });

  final DateTime startsAt;
  final bool expanded;
  final String formattedValue;
  final VoidCallback onToggle;
  final ValueChanged<int> onDateOffset;
  final ValueChanged<int> onAdjustMinutes;
  final void Function(int hour, int minute) onSpecificTime;
  final VoidCallback onCustomDate;
  final VoidCallback onCustomTime;

  int get _selectedOffset {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(startsAt.year, startsAt.month, startsAt.day);
    return selected.difference(today).inDays;
  }

  String _relativeDateLabel(String prefix, int offset) {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day + offset);
    return "$prefix · ${date.month}/${date.day}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EnsomColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: EnsomColors.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.schedule,
                      size: 14,
                      color: EnsomColors.inkMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "시작 시각",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: EnsomColors.ink,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      formattedValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: EnsomColors.inkMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: expanded ? .25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: EnsomColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FormSectionLabel("날짜"),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _QuickTimeChip(
                        label: _relativeDateLabel("오늘", 0),
                        selected: _selectedOffset == 0,
                        onTap: () => onDateOffset(0),
                      ),
                      _QuickTimeChip(
                        label: _relativeDateLabel("내일", 1),
                        selected: _selectedOffset == 1,
                        onTap: () => onDateOffset(1),
                      ),
                      _QuickTimeChip(
                        label: _relativeDateLabel("모레", 2),
                        selected: _selectedOffset == 2,
                        onTap: () => onDateOffset(2),
                      ),
                      _QuickTimeChip(label: "직접 선택", onTap: onCustomDate),
                    ],
                  ),
                  const _FormSectionLabel("시각 빠르게 조정"),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _QuickTimeChip(
                        label: "+30분",
                        onTap: () => onAdjustMinutes(30),
                      ),
                      _QuickTimeChip(
                        label: "+1시간",
                        onTap: () => onAdjustMinutes(60),
                      ),
                      _QuickTimeChip(
                        label: "오전 9:00",
                        onTap: () => onSpecificTime(9, 0),
                      ),
                      _QuickTimeChip(
                        label: "오후 12:00",
                        onTap: () => onSpecificTime(12, 0),
                      ),
                      _QuickTimeChip(
                        label: "오후 6:00",
                        onTap: () => onSpecificTime(18, 0),
                      ),
                      _QuickTimeChip(label: "직접 선택", onTap: onCustomTime),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: .4,
          color: EnsomColors.inkFaint,
        ),
      ),
    );
  }
}

class _QuickTimeChip extends StatelessWidget {
  const _QuickTimeChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? EnsomColors.cta : EnsomColors.surface2,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : EnsomColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// 목업 `.vrow` — hairline 테두리(1.4px), radius 12의 값 표시 행.
class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.value,
    required this.onTap,
    this.hint = false,
    this.leading,
    this.trailing = Icons.chevron_right,
  });

  final String value;
  final bool hint;
  final VoidCallback onTap;
  final IconData? leading;
  final IconData trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EnsomColors.hairline, width: 1.4),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              Icon(leading, size: 16, color: EnsomColors.inkFaint),
              const SizedBox(width: 9),
            ],
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: hint ? FontWeight.w500 : FontWeight.w600,
                  color: hint ? EnsomColors.inkFaint : EnsomColors.ink,
                ),
              ),
            ),
            Icon(trailing, size: 16, color: EnsomColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// §3 S-10 "저장할 캘린더 선택 — 라디오. 이동 없음".
///
/// 연동한 캘린더가 없으면 아무것도 그리지 않는다. 고를 게 하나뿐인데 선택지를
/// 보여주면 결정할 일이 있는 것처럼 보인다.
class _CalendarTargetPicker extends ConsumerWidget {
  const _CalendarTargetPicker({
    required this.selectedId,
    required this.onSelected,
  });

  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(calendarConnectionsProvider);
    // 목록을 못 읽어도 일정 저장은 막지 않는다. 서버가 기본 캘린더에 기록한다.
    final sources = connections.asData?.value.writableSources ?? const [];
    if (sources.length < 2) return const SizedBox.shrink();

    final defaultSource = connections.asData!.value.defaultWritableSource;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Text(
          "저장할 캘린더",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: EnsomColors.inkMuted,
          ),
        ),
        const SizedBox(height: 8),
        for (final source in sources)
          RadioListTile<String?>(
            value: source.calendarSourceId,
            // 아직 고르지 않았으면 서버 기본값이 선택된 것으로 보여준다.
            groupValue: selectedId ?? defaultSource?.calendarSourceId,
            onChanged: onSelected,
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: EnsomColors.cta,
            title: Text(
              source.displayName,
              style: const TextStyle(fontSize: 12.5, color: EnsomColors.ink),
            ),
          ),
      ],
    );
  }
}
