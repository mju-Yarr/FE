import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";
import "../../models/event.dart";
import "../../network/api_client.dart";
import "../../providers/auth_providers.dart";
import "../../providers/bootstrap_provider.dart";
import "../../providers/calendar_providers.dart";
import "widgets/classification_review_sheet.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_wordmark.dart";
import "../../widgets/permission_degraded_banner.dart";

enum _CalView { week, month }

enum _EventFilter { all, move, online }

enum _SyncBannerStatus { idle, syncing, failed }

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _monthOf(DateTime d) => DateTime(d.year, d.month, 1);

/// S-09 캘린더. 명세(ensom_calendar.html v2)의 다크 패널 기반
/// 주간·월간 전환(드래그+탭 둘 다 지원, §13-13 "드래그에는 버튼 대안"),
/// 날짜별 필터링, 검색 오버레이를 반영한다.
///
/// "환승 1회 · 42분 · 12:40 준비 시작" 같은 카드 하단 경로 요약은
/// 일부러 뺐다 — 그건 활성 계획(Plan) 데이터가 있어야 하는데, 이 화면은
/// 한 달 치 Event만 일괄 조회하고 날짜별로 Plan/경로를 계산해 주는
/// API가 없다(오늘의 활성 계획만 홈 화면에 별도로 있음). 대신 카드에는
/// Event.locationState로 판단할 수 있는 이동 여부 배지만 남겼다.
/// "이번 주 리포트" 카드도 실제 집계 API가 아직 없어(WeeklyReportScreen
/// 자체가 "BE API 미정" 플레이스홀더) 숫자를 지어내지 않고 그 화면으로
/// 연결만 한다.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _CalView _view = _CalView.week;
  DateTime _focusedMonth = _monthOf(DateTime.now());
  late DateTime _selectedDate = _dateOnly(DateTime.now());
  _EventFilter _filter = _EventFilter.all;
  bool _searchOpen = false;
  _SyncBannerStatus _syncStatus = _SyncBannerStatus.idle;
  DateTime? _syncFailedAt;

  // 선택한 날이 있는 달의 앞뒤 한 달씩을 같이 불러온다 — 주간 뷰가 달
  // 경계를 넘나들 때, 그리고 검색 오버레이가 뒤질 범위를 위해서다.
  EventRange get _fetchRange => EventRange(
    from: DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1),
    to: DateTime(_focusedMonth.year, _focusedMonth.month + 2, 1),
  );

  @override
  void initState() {
    super.initState();
    _syncIfConnected();
  }

  /// ensom_calendar_syncbanner.html — 구글 캘린더가 연동돼 있을 때만
  /// 동기화를 시도한다. `POST /calendar/sync`는 응답 형태가 문서화돼
  /// 있지 않아(§7 표에 경로만 있음) 성공/실패만으로 배너 상태를 가른다.
  /// 실패해도 이미 가진 일정 목록은 그대로 두고 배너로만 알린다(§1.5).
  Future<void> _syncIfConnected() async {
    final api = ref.read(apiClientProvider);
    try {
      final status = await api.get<Map<String, dynamic>>(
        "/calendar/google/status",
      );
      if (status["connected"] != true) return;
    } on ApiException catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _syncStatus = _SyncBannerStatus.syncing);
    try {
      await api.post("/calendar/sync");
      if (!mounted) return;
      setState(() => _syncStatus = _SyncBannerStatus.idle);
      ref.invalidate(eventsInRangeProvider(_fetchRange));
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() {
        _syncStatus = _SyncBannerStatus.failed;
        _syncFailedAt = DateTime.now();
      });
    }
  }

  void _selectDate(DateTime d) {
    setState(() {
      _selectedDate = _dateOnly(d);
      _focusedMonth = _monthOf(_selectedDate);
    });
  }

  void _shiftWeek(int deltaWeeks) =>
      _selectDate(_selectedDate.add(Duration(days: 7 * deltaWeeks)));

  void _shiftMonth(int deltaMonths) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + deltaMonths,
        1,
      );
      final lastDay = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + 1,
        0,
      ).day;
      final day = _selectedDate.day.clamp(1, lastDay);
      _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, day);
    });
  }

  void _toggleView() => setState(
    () => _view = _view == _CalView.week ? _CalView.month : _CalView.week,
  );

  bool _matchesFilter(Event e) {
    switch (_filter) {
      case _EventFilter.all:
        return true;
      case _EventFilter.online:
        return e.locationState == LocationState.notRequired;
      case _EventFilter.move:
        return e.locationState != LocationState.notRequired;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsInRangeProvider(_fetchRange));
    final bootstrap = ref.watch(bootstrapProvider).value;
    final calendarStatuses = bootstrap?.permissions.where(
      (permission) => permission.permissionType == "calendar",
    );
    final calendarDenied =
        calendarStatuses?.any(
          (permission) =>
              permission.status == "denied" ||
              permission.status == "restricted",
        ) ??
        false;

    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      floatingActionButton: _searchOpen
          ? null
          : FloatingActionButton(
              backgroundColor: EnsomColors.cta,
              onPressed: () => context.push("/calendar/new"),
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: SafeArea(
        child: Stack(
          children: [
            eventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text("불러오지 못했어요: $err")),
              data: (events) => _buildBody(events, calendarDenied),
            ),
            if (_searchOpen)
              _SearchOverlay(
                events: eventsAsync.value ?? const [],
                onClose: () => setState(() => _searchOpen = false),
                onPick: _selectDate,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<Event> events, bool calendarDenied) {
    final eventsByDay = <DateTime, List<Event>>{};
    for (final e in events) {
      eventsByDay.putIfAbsent(_dateOnly(e.startsAt), () => []).add(e);
    }
    for (final list in eventsByDay.values) {
      list.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    }

    final selectedEvents = (eventsByDay[_selectedDate] ?? const <Event>[])
        .where(_matchesFilter)
        .toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                if (_syncStatus != _SyncBannerStatus.idle) ...[
                  const SizedBox(height: 10),
                  _SyncBanner(
                    status: _syncStatus,
                    failedAt: _syncFailedAt,
                    onRetry: _syncIfConnected,
                  ),
                ],
                // S-11 — 동기화가 분류를 확신하지 못한 일정. 배너는 다크 패널
                // 위쪽 흰 영역에 둔다(§3 S-09).
                _PendingReviewBanner(range: _fetchRange),
                const SizedBox(height: 14),
                _CalendarPanel(
                  view: _view,
                  focusedMonth: _focusedMonth,
                  selectedDate: _selectedDate,
                  eventCountOf: (d) => eventsByDay[d]?.length ?? 0,
                  onSelectDate: _selectDate,
                  onPrev: () =>
                      _view == _CalView.week ? _shiftWeek(-1) : _shiftMonth(-1),
                  onNext: () =>
                      _view == _CalView.week ? _shiftWeek(1) : _shiftMonth(1),
                  onToggleView: _toggleView,
                  onDragToView: (v) => setState(() => _view = v),
                ),
                const SizedBox(height: 16),
                _filterRow(),
                const SizedBox(height: 12),
                _ReportCard(
                  onTap: () => context.push(
                    "/calendar/weekly-report?date=${DateFormat("yyyy-MM-dd").format(_selectedDate)}",
                  ),
                ),
                const SizedBox(height: 4),
                PermissionDegradedBanner(
                  type: DegradedPermissionType.calendar,
                  deniedOverride: calendarDenied,
                ),
                const SizedBox(height: 10),
                _dayLabel(),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
        if (selectedEvents.isEmpty)
          SliverToBoxAdapter(child: _emptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _TimelineRow(
                  event: selectedEvents[i],
                  isLast: i == selectedEvents.length - 1,
                  hot: _isHot(selectedEvents, i),
                  onTap: () =>
                      context.push("/events/${selectedEvents[i].eventId}"),
                ),
                childCount: selectedEvents.length,
              ),
            ),
          ),
      ],
    );
  }

  bool _isHot(List<Event> dayEvents, int index) {
    if (_selectedDate != _dateOnly(DateTime.now())) return false;
    final now = DateTime.now();
    // 종료 시각이 없으면 시작 시각을 기준으로 본다.
    final nextIndex = dayEvents.indexWhere(
      (e) => (e.endsAt ?? e.startsAt).isAfter(now),
    );
    return nextIndex == index;
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const EnsomWordmark(fontSize: 15),
        Row(
          children: [
            _IconAction(
              icon: Icons.search,
              tooltip: "일정 검색",
              onTap: () => setState(() => _searchOpen = true),
            ),
            const SizedBox(width: 7),
            _IconAction(
              icon: Icons.bar_chart_outlined,
              tooltip: "이번 주 리포트",
              onTap: () => context.push("/calendar/weekly-report"),
            ),
            const SizedBox(width: 7),
            _IconAction(
              icon: Icons.sync,
              tooltip: "캘린더 연동 관리",
              onTap: () => context.push("/calendar/connections"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterRow() {
    return Row(
      children: [
        _FilterChip(
          label: "전체",
          selected: _filter == _EventFilter.all,
          onTap: () => setState(() => _filter = _EventFilter.all),
        ),
        const SizedBox(width: 6),
        _FilterChip(
          label: "이동 있음",
          selected: _filter == _EventFilter.move,
          onTap: () => setState(() => _filter = _EventFilter.move),
        ),
        const SizedBox(width: 6),
        _FilterChip(
          label: "온라인",
          selected: _filter == _EventFilter.online,
          onTap: () => setState(() => _filter = _EventFilter.online),
        ),
      ],
    );
  }

  static final _dayLabelFmt = DateFormat("M월 d일", "ko_KR");
  static final _weekdayFmt = DateFormat("EEEE", "ko_KR");

  Widget _dayLabel() {
    final isToday = _selectedDate == _dateOnly(DateTime.now());
    final label =
        "${_dayLabelFmt.format(_selectedDate)} ${_weekdayFmt.format(_selectedDate)}${isToday ? ' · 오늘' : ''}";
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: EnsomColors.inkFaint,
        letterSpacing: .2,
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 36, bottom: 100),
      child: Column(
        children: [
          Icon(Icons.event_available, size: 40, color: EnsomColors.inkFaint),
          SizedBox(height: 12),
          Text(
            "이 날은 등록된 일정이 없어요",
            style: TextStyle(fontSize: 12.5, color: EnsomColors.inkFaint),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            "아래 + 버튼으로 추가할 수 있어요",
            style: TextStyle(fontSize: 12.5, color: EnsomColors.inkFaint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: EnsomColors.surface2,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 15, color: EnsomColors.ink),
          ),
        ),
      ),
    );
  }
}

/// ensom_calendar_syncbanner.html — "동기화 중" 스피너 배너와 "일부 실패"
/// 재시도 배너 2종(정상 상태는 배너 자체가 없는 것으로 표현).
class _SyncBanner extends StatelessWidget {
  const _SyncBanner({
    required this.status,
    required this.failedAt,
    required this.onRetry,
  });

  final _SyncBannerStatus status;
  final DateTime? failedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(15),
      ),
      child: status == _SyncBannerStatus.syncing
          ? Row(
              children: const [
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: EnsomColors.inkMuted,
                  ),
                ),
                SizedBox(width: 9),
                Text(
                  "일정을 가져오는 중",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: EnsomColors.inkMuted,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "일부 일정을 가져오지 못했어요"
                    "${failedAt == null ? '' : ' · ${failedAt!.hour.toString().padLeft(2, '0')}:${failedAt!.minute.toString().padLeft(2, '0')} 기준'}",
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: EnsomColors.inkMuted,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onRetry,
                  child: const Text(
                    "다시 시도",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: EnsomColors.ink,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? EnsomColors.cta : EnsomColors.surface2,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : EnsomColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EnsomColors.surface2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "이번 주 리포트",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.2,
                        color: EnsomColors.ink,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "도착 흐름을 돌아보는 기록이에요",
                      style: TextStyle(
                        fontSize: 11,
                        color: EnsomColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: EnsomColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// 다크 캘린더 패널. 주간·월간 그리드와 손잡이(pgrip)를 담는다.
/// 손잡이는 드래그(22px 이상 움직이면 전환)와 탭(안 움직였으면 토글)을
/// 모두 처리한다 — JS 원본의 pointerdown/move/up 로직과 동일하다.
class _CalendarPanel extends StatefulWidget {
  const _CalendarPanel({
    required this.view,
    required this.focusedMonth,
    required this.selectedDate,
    required this.eventCountOf,
    required this.onSelectDate,
    required this.onPrev,
    required this.onNext,
    required this.onToggleView,
    required this.onDragToView,
  });

  final _CalView view;
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final int Function(DateTime) eventCountOf;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToggleView;
  final ValueChanged<_CalView> onDragToView;

  @override
  State<_CalendarPanel> createState() => _CalendarPanelState();
}

class _CalendarPanelState extends State<_CalendarPanel> {
  static const _dow = ["일", "월", "화", "수", "목", "금", "토"];

  double _dragAccum = 0;
  bool _dragTriggered = false;

  List<DateTime> get _weekDates {
    final d = widget.selectedDate;
    final start = d.subtract(Duration(days: d.weekday % 7));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  String _weekOfMonthLabel(DateTime d) {
    final weekNum = ((d.day - 1) ~/ 7) + 1;
    return "${d.month}월 $weekNum주";
  }

  @override
  Widget build(BuildContext context) {
    final isWeek = widget.view == _CalView.week;
    final today = _dateOnly(DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
      decoration: BoxDecoration(
        color: EnsomColors.panel,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isWeek
                        ? "${widget.selectedDate.month}월 ${widget.selectedDate.day}일"
                        : "${widget.focusedMonth.month}월",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isWeek
                        ? "${widget.focusedMonth.year} · ${_weekOfMonthLabel(widget.selectedDate)}"
                        : "${widget.focusedMonth.year}",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .45),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: .2,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _PanelNavButton(
                    icon: Icons.chevron_left,
                    solid: false,
                    onTap: widget.onPrev,
                  ),
                  const SizedBox(width: 6),
                  _PanelNavButton(
                    icon: Icons.chevron_right,
                    solid: true,
                    onTap: widget.onNext,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isWeek) ...[_dowRow(), const SizedBox(height: 9)],
          isWeek ? _weekGrid(today) : _monthGrid(today),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) {
              _dragAccum = 0;
              _dragTriggered = false;
            },
            onVerticalDragUpdate: (details) {
              if (_dragTriggered) return;
              _dragAccum += details.delta.dy;
              if (_dragAccum.abs() < 22) return;
              _dragTriggered = true;
              widget.onDragToView(
                _dragAccum > 0 ? _CalView.month : _CalView.week,
              );
            },
            onVerticalDragEnd: (_) {
              _dragAccum = 0;
              _dragTriggered = false;
            },
            onTap: () {
              if (!_dragTriggered) widget.onToggleView();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .30),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isWeek ? "아래로 끌어 월간 보기" : "위로 끌어 주간 보기",
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: .38),
                      letterSpacing: .2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dowRow() {
    return Row(
      children: _dow
          .map(
            (d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: .38),
                    letterSpacing: .5,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _weekGrid(DateTime today) {
    return Row(
      children: _weekDates.map((d) {
        return Expanded(
          child: Column(
            children: [
              Text(
                _dow[d.weekday % 7],
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: .38),
                  letterSpacing: .4,
                ),
              ),
              const SizedBox(height: 6),
              _DayDot(
                date: d,
                today: today,
                selected: widget.selectedDate,
                count: widget.eventCountOf(d),
                onTap: () => widget.onSelectDate(d),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _monthGrid(DateTime today) {
    final monthStart = DateTime(
      widget.focusedMonth.year,
      widget.focusedMonth.month,
      1,
    );
    final leading = monthStart.weekday % 7;
    final daysInMonth = DateTime(
      widget.focusedMonth.year,
      widget.focusedMonth.month + 1,
      0,
    ).day;
    final gridStart = monthStart.subtract(Duration(days: leading));
    final totalCells = leading + daysInMonth;
    final cellCount = (totalCells / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cellCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 7,
        mainAxisExtent: 33,
      ),
      itemBuilder: (context, i) {
        final date = gridStart.add(Duration(days: i));
        final inMonth = date.month == widget.focusedMonth.month;
        if (!inMonth) {
          return Center(
            child: Text(
              "${date.day}",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: .18),
              ),
            ),
          );
        }
        return Center(
          child: _DayDot(
            date: date,
            today: today,
            selected: widget.selectedDate,
            count: widget.eventCountOf(date),
            onTap: () => widget.onSelectDate(date),
          ),
        );
      },
    );
  }
}

class _PanelNavButton extends StatelessWidget {
  const _PanelNavButton({
    required this.icon,
    required this.solid,
    required this.onTap,
  });

  final IconData icon;
  final bool solid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: solid ? EnsomColors.lime : Colors.white.withValues(alpha: .09),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 16,
            color: solid ? EnsomColors.ink : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.date,
    required this.today,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final DateTime date;
  final DateTime today;
  final DateTime selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = date == today;
    final isSelected = date == selected && !isToday;
    final hasEvents = count > 0;

    Color bg = Colors.transparent;
    Color border = Colors.transparent;
    Color fg = Colors.white.withValues(alpha: .72);
    var weight = FontWeight.w600;
    if (isToday) {
      bg = EnsomColors.lime;
      border = EnsomColors.lime;
      fg = EnsomColors.ink;
      weight = FontWeight.w700;
    } else if (isSelected) {
      bg = Colors.white;
      border = Colors.white;
      fg = EnsomColors.ink;
      weight = FontWeight.w700;
    } else if (hasEvents) {
      border = EnsomColors.lime.withValues(alpha: .42);
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 33,
            height: 33,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 1.4),
            ),
            child: Text(
              "${date.day}",
              style: TextStyle(fontSize: 12.5, fontWeight: weight, color: fg),
            ),
          ),
          if (count > 1)
            Positioned(
              bottom: -1,
              right: -1,
              child: Container(
                width: 13,
                height: 13,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (isToday || isSelected)
                      ? EnsomColors.cta
                      : EnsomColors.lime,
                  shape: BoxShape.circle,
                  border: Border.all(color: EnsomColors.panel, width: 1.5),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: (isToday || isSelected)
                        ? Colors.white
                        : EnsomColors.ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isLast,
    required this.hot,
    required this.onTap,
  });

  final Event event;
  final bool isLast;
  final bool hot;
  final VoidCallback onTap;

  static final _timeFmt = DateFormat("h:mm", "ko_KR");
  static final _meridiemFmt = DateFormat("a", "ko_KR");

  @override
  Widget build(BuildContext context) {
    final isOnline = event.locationState == LocationState.notRequired;
    final needsPlace = event.locationState == LocationState.requiredMissing;

    late final String pillLabel;
    late final Color pillBg;
    late final Color pillFg;
    if (needsPlace) {
      pillLabel = "장소 필요";
      pillBg = EnsomColors.caution;
      pillFg = EnsomColors.ink;
    } else if (isOnline) {
      pillLabel = "이동 없음";
      pillBg = EnsomColors.surface2;
      pillFg = EnsomColors.inkMuted;
    } else {
      pillLabel = "이동 있음";
      pillBg = EnsomColors.limeSoft;
      pillFg = EnsomColors.limeInk;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(
                    _timeFmt.format(event.startsAt),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.2,
                      color: EnsomColors.ink,
                    ),
                  ),
                  Text(
                    _meridiemFmt.format(event.startsAt),
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: EnsomColors.inkFaint,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Expanded(
                    child: Container(
                      width: 1.5,
                      decoration: BoxDecoration(
                        color: isLast ? null : EnsomColors.hairline,
                        gradient: isLast
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  EnsomColors.hairline,
                                  EnsomColors.hairline.withValues(alpha: 0),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Material(
                color: EnsomColors.surface1,
                borderRadius: BorderRadius.circular(19),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(19),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                        color: hot ? EnsomColors.cta : EnsomColors.hairline,
                        width: hot ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.25,
                                  color: EnsomColors.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    isOnline
                                        ? Icons.videocam_outlined
                                        : Icons.place_outlined,
                                    size: 11,
                                    color: EnsomColors.inkFaint,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      isOnline
                                          ? "온라인"
                                          : (event.destinationName ?? "장소 미정"),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: EnsomColors.inkMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            pillLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: pillFg,
                              letterSpacing: .1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// S-09 검색 오버레이. 이미 불러온(현재 달 앞뒤 포함 3개월치) 이벤트
/// 안에서만 이름/장소로 실시간 필터링한다 — 서버 검색 엔드포인트가
/// 없어서 전체 기간 검색은 지원하지 않는다.
class _SearchOverlay extends StatefulWidget {
  const _SearchOverlay({
    required this.events,
    required this.onClose,
    required this.onPick,
  });

  final List<Event> events;
  final VoidCallback onClose;
  final ValueChanged<DateTime> onPick;

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<_SearchOverlay> {
  final _controller = TextEditingController();
  String _query = "";

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final hits = q.isEmpty
        ? [...widget.events]
        : widget.events
              .where(
                (e) =>
                    e.displayName.toLowerCase().contains(q) ||
                    (e.destinationName?.toLowerCase().contains(q) ?? false),
              )
              .toList();
    hits.sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return Positioned.fill(
      child: Material(
        color: EnsomColors.canvas,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _IconAction(
                      icon: Icons.arrow_back,
                      tooltip: "닫기",
                      onTap: widget.onClose,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "일정 검색",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
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
                          onChanged: (v) => setState(() => _query = v),
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: EnsomColors.ink,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "일정 이름, 장소",
                            isCollapsed: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: hits.isEmpty
                      ? Center(
                          child: Text(
                            q.isEmpty ? "등록된 일정이 없어요" : "'$q'와 맞는 일정이 없어요",
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: EnsomColors.inkMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          itemCount: hits.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: EnsomColors.hairline,
                          ),
                          itemBuilder: (context, i) {
                            final e = hits[i];
                            final isOnline =
                                e.locationState == LocationState.notRequired;
                            return InkWell(
                              onTap: () => widget.onPick(e.startsAt),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 38,
                                      child: Text(
                                        "${e.startsAt.month}/${e.startsAt.day}",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: EnsomColors.inkMuted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            e.displayName,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -.2,
                                              color: EnsomColors.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            "${DateFormat("HH:mm").format(e.startsAt)} · ${isOnline ? '온라인' : (e.destinationName ?? '장소 미정')}",
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

/// S-11 진입점 — 동기화가 분류를 확신하지 못한 일정을 알린다.
///
/// §3 S-09 "동기화 일부 실패 시 전면 오류 화면을 쓰지 않는다"와 같은 이유로,
/// 목록을 못 읽으면 조용히 아무것도 그리지 않는다. 캘린더 자체는 계속 쓸 수 있다.
class _PendingReviewBanner extends ConsumerWidget {
  const _PendingReviewBanner({required this.range});

  final EventRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(pendingReviewsProvider(range)).value;
    if (reviews == null || reviews.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showClassificationReviewSheet(context, reviews.first),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.help_outline,
                  size: 16,
                  color: EnsomColors.inkMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    reviews.length == 1
                        ? "확인이 필요한 일정이 하나 있어요"
                        : "확인이 필요한 일정이 ${reviews.length}개 있어요",
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.2,
                      color: EnsomColors.ink,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: EnsomColors.inkFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
