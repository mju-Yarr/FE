import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_riverpod/legacy.dart";
import "package:go_router/go_router.dart";
import "../../core/local_notification_service.dart";
import "../../models/event.dart";
import "../../models/plan.dart";
import "../../network/api_client.dart";
import "../../providers/calendar_providers.dart";
import "../calendar/widgets/classification_review_sheet.dart";
import "../../providers/home_providers.dart";
import "../../repository/providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_error_banner.dart";
import "../../widgets/ensom/ensom_pill_button.dart";
import "../../widgets/permission_degraded_banner.dart";
import "../../widgets/plan_edit_sheet.dart";
import "../../widgets/prep_item_add_sheet.dart";
import "../../widgets/route_change_sheet.dart";
import "../home/widgets/arrival_result_card.dart";
import "../home/widgets/checklist_section.dart";
import "../home/widgets/wellness_actions_section.dart";

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return LocalNotificationService.instance;
});

final eventDeletionInProgressProvider = StateProvider.autoDispose
    .family<bool, String>((ref, eventId) => false);

/// DTL-01 일정 상세 (S-12)
/// 진입: HM-01 카드 탭, CAL-01 카드 탭, HM-02 알림 행
/// BE API: GET /events/{id}, GET /events/{id}/plans/latest
///
/// ensom_detail.html 반영 — 캘린더 화면과 같은 다크 패널 컴포넌트로
/// "시간 계획"을 보여준다(§노트 "두 화면이 같은 앱으로 묶이는 장치").
/// 계획 fetch/체크리스트·웰니스 resolve는 home_screen.dart와 동일하게
/// planControllerProvider를 공유한다 — 오프라인 큐·낙관적 갱신이 이미
/// 구현돼 있는 그 컨트롤러를 그대로 재사용해서, 이 화면만의 별도 API
/// 호출 경로를 새로 만들지 않는다.
///
/// 결과(종료 후 사후평가) 섹션은 `ArrivalResultCard`를 그대로 재사용한다
/// (홈 카드와 동일 위젯). "계획 수정" 메뉴는 `PlanEditSheet`로 연결했다
/// (PLAN-04, 준비 시작 시각만 — 출발지 선택은 §PlanEditSheet 문서 참고).
/// 하단 "준비 시작" 액션바는 여전히 넣지 않았다.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  static const _terminalStatuses = {
    EventLifecycleStatus.arrived,
    EventLifecycleStatus.closed,
    EventLifecycleStatus.skipped,
    EventLifecycleStatus.cancelled,
    EventLifecycleStatus.unresolved,
  };

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(eventDetailProvider(eventId));
    await ref.read(planControllerProvider(eventId).notifier).retry();
  }

  Future<void> _resolveChecklistItem(
    BuildContext context,
    WidgetRef ref,
    ChecklistItem item,
    bool completed,
  ) async {
    try {
      await ref
          .read(planControllerProvider(eventId).notifier)
          .toggleChecklistItem(item, completed);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("처리하지 못했어요. 다시 시도해주세요.")));
    }
  }

  Future<void> _resolveWellnessAction(
    BuildContext context,
    WidgetRef ref,
    WellnessAction action,
    WellnessActionCompletionStatus status,
  ) async {
    try {
      await ref
          .read(planControllerProvider(eventId).notifier)
          .resolveWellnessAction(action, status);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("처리하지 못했어요. 다시 시도해주세요.")));
    }
  }

  void _onMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case "edit":
        _openPlanEditSheet(context, ref);
        break;
      case "delete":
        _showDeleteConfirm(context, ref);
        break;
    }
  }

  Future<void> _openPlanEditSheet(BuildContext context, WidgetRef ref) async {
    final plan = ref.read(planControllerProvider(eventId)).value;
    if (plan == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: EnsomColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) =>
          PlanEditSheet(eventId: eventId, initialPrepStartAt: plan.prepStartAt),
    );
    if (saved == true) {
      // PlanEditSheet's controller already contains the PATCH response. Keep
      // that authoritative revision instead of discarding it and racing a
      // second GET against the just-completed update.
      ref.invalidate(todayPlanProvider);
      ref.invalidate(nextEventProvider);
    }
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref) {
    if (ref.read(eventDeletionInProgressProvider(eventId))) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("이 일정을 삭제할까요?"),
        content: const Text("예약된 알림도 함께 취소돼요."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteEvent(context, ref);
            },
            style: TextButton.styleFrom(foregroundColor: EnsomColors.caution),
            child: const Text("삭제"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(BuildContext context, WidgetRef ref) async {
    final deletionState = ref.read(
      eventDeletionInProgressProvider(eventId).notifier,
    );
    if (deletionState.state) return;
    deletionState.state = true;

    try {
      await ref.read(ensomRepositoryProvider).deleteEvent(eventId);
      await ref
          .read(localNotificationServiceProvider)
          .cancelPlanNotifications(eventId: eventId);
      ref.invalidate(eventDetailProvider(eventId));
      ref.invalidate(planControllerProvider(eventId));
      ref.invalidate(eventsInRangeProvider);
      ref.invalidate(pendingReviewsProvider);
      ref.invalidate(weeklySummaryProvider);
      ref.invalidate(todayPlanProvider);
      ref.invalidate(nextEventProvider);
      if (context.mounted) {
        deletionState.state = false;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("삭제했어요.")));
        context.pop(true);
      }
    } on ApiException catch (e) {
      if (!context.mounted) return;
      deletionState.state = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      deletionState.state = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("삭제를 마무리하지 못했어요. 다시 시도해주세요.")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final isDeleting = ref.watch(eventDeletionInProgressProvider(eventId));

    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: AppBar(
        backgroundColor: EnsomColors.canvas,
        surfaceTintColor: EnsomColors.canvas,
        elevation: 0,
        title: const Text(
          "일정 상세",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: EnsomColors.ink,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            enabled: !isDeleting,
            onSelected: (action) => _onMenuAction(context, ref, action),
            icon: isDeleting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.more_horiz, color: EnsomColors.ink),
            itemBuilder: (context) => [
              const PopupMenuItem(value: "edit", child: Text("계획 수정")),
              const PopupMenuItem(
                value: "delete",
                child: Text(
                  "일정 삭제",
                  style: TextStyle(color: EnsomColors.caution),
                ),
              ),
            ],
          ),
        ],
      ),
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => _ErrorState(onRetry: () => _refresh(ref)),
        data: (event) => RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              const PermissionDegradedBanner(
                type: DegradedPermissionType.location,
              ),
              _Header(event: event),
              // §3 S-11 진입 3경로 중 하나. 분류가 미정인 일정은 상세에서도
              // 확인할 수 있어야 한다.
              _ClassificationPrompt(event: event),
              const SizedBox(height: 18),
              Consumer(
                builder: (context, ref, _) {
                  final planAsync = ref.watch(planControllerProvider(eventId));
                  return planAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, st) {
                      if (err is ApiException && err.statusCode == 404) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              "이 일정은 이동 계획이 없어요.",
                              style: TextStyle(color: EnsomColors.inkMuted),
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: EnsomErrorBanner(
                          title: "계획을 불러오지 못했어요",
                          subtitle: err.toString(),
                        ),
                      );
                    },
                    data: (plan) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TimePlanPanel(
                          plan: plan,
                          isTerminal: _terminalStatuses.contains(
                            plan.eventStatus,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _BreakdownCard(breakdown: plan.breakdown),
                        const SizedBox(height: 18),
                        ChecklistSection(
                          checklist: plan.checklist,
                          onToggle: (item, completed) => _resolveChecklistItem(
                            context,
                            ref,
                            item,
                            completed,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              final added = await showModalBottomSheet<bool>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => const PrepItemAddSheet(),
                              );
                              if (added == true)
                                ref.invalidate(planControllerProvider(eventId));
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text(
                              "준비 항목 추가",
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        if (plan.wellnessActions.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          WellnessActionsSection(
                            actions: plan.wellnessActions,
                            onResolve: (action, status) =>
                                _resolveWellnessAction(
                                  context,
                                  ref,
                                  action,
                                  status,
                                ),
                          ),
                        ],
                        if (plan.selectedRouteOptionId != null) ...[
                          const SizedBox(height: 18),
                          _RouteSummaryCard(plan: plan, eventId: eventId),
                        ],
                        if (_terminalStatuses.contains(plan.eventStatus)) ...[
                          const SizedBox(height: 18),
                          ArrivalResultCard(eventId: eventId),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "불러오지 못했어요.",
            style: TextStyle(color: EnsomColors.inkMuted),
          ),
          const SizedBox(height: 14),
          EnsomPillButton(label: "다시 시도", expand: false, onPressed: onRetry),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.event});

  final Event event;

  static const _statusLabels = {
    EventLifecycleStatus.enroute: "이동 중",
    EventLifecycleStatus.arrived: "도착",
    EventLifecycleStatus.closed: "완료",
    EventLifecycleStatus.skipped: "건너뜀",
    EventLifecycleStatus.cancelled: "취소됨",
    EventLifecycleStatus.unresolved: "확인 필요",
  };

  @override
  Widget build(BuildContext context) {
    final status = event.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.displayName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -.6,
            height: 1.2,
            color: EnsomColors.ink,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            if (status != null && _statusLabels[status] != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      status == EventLifecycleStatus.closed ||
                          status == EventLifecycleStatus.arrived
                      ? EnsomColors.cta
                      : EnsomColors.surface2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabels[status]!,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color:
                        status == EventLifecycleStatus.closed ||
                            status == EventLifecycleStatus.arrived
                        ? Colors.white
                        : EnsomColors.inkMuted,
                  ),
                ),
              ),
            Text(
              _formatMeta(event),
              style: const TextStyle(
                fontSize: 12.5,
                color: EnsomColors.inkMuted,
              ),
            ),
          ],
        ),
        if (event.destinationName != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 14,
                color: EnsomColors.inkFaint,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  event.destinationName!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: EnsomColors.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatMeta(Event event) {
    final start = event.startsAt.toLocal();
    final h1 = start.hour.toString().padLeft(2, "0");
    final m1 = start.minute.toString().padLeft(2, "0");
    final end = event.endsAt?.toLocal();
    // 종료 시각이 없으면 범위 대신 시작 시각만 적는다. 없는 시각을 지어내지 않는다.
    if (end == null) return "${start.month}월 ${start.day}일 · $h1:$m1";
    final h2 = end.hour.toString().padLeft(2, "0");
    final m2 = end.minute.toString().padLeft(2, "0");
    return "${start.month}월 ${start.day}일 · $h1:$m1–$h2:$m2";
  }
}

/// 목업 `.tpanel` — 캘린더 다크 패널과 같은 컴포넌트를 재사용해
/// "하루의 계획 전체"를 보여준다. 준비시작·출발·도착 세 지점을 트랙
/// 위 노드로 찍고, 지금 시각까지만 라임으로 채운다.
class _TimePlanPanel extends StatelessWidget {
  const _TimePlanPanel({required this.plan, required this.isTerminal});

  final Plan plan;
  final bool isTerminal;

  int get _activeIndex {
    if (isTerminal) return 2;
    final now = DateTime.now();
    if (now.isBefore(plan.prepStartAt)) return 0;
    if (now.isBefore(plan.recommendedDepartAt)) return 1;
    return 2;
  }

  String get _headline {
    if (isTerminal) return _terminalMessage(plan.eventStatus);
    final now = DateTime.now();
    if (now.isBefore(plan.prepStartAt)) {
      final m = plan.prepStartAt.difference(now).inMinutes;
      return m > 0 ? "$m분 뒤 준비를 시작하세요" : "곧 준비를 시작하세요";
    }
    if (now.isBefore(plan.recommendedDepartAt)) {
      final m = plan.recommendedDepartAt.difference(now).inMinutes;
      return m > 0 ? "$m분 뒤 출발하세요" : "곧 출발하세요";
    }
    if (now.isBefore(plan.targetArriveAt)) {
      final m = plan.targetArriveAt.difference(now).inMinutes;
      return m > 0 ? "$m분 뒤 도착 예정이에요" : "곧 도착할 예정이에요";
    }
    return "도착 확인 중이에요";
  }

  static String _terminalMessage(EventLifecycleStatus status) {
    switch (status) {
      case EventLifecycleStatus.arrived:
      case EventLifecycleStatus.closed:
        return "완료됐어요";
      case EventLifecycleStatus.skipped:
        return "이 일정은 건너뛰었어요";
      case EventLifecycleStatus.cancelled:
        return "이 일정은 취소됐어요";
      case EventLifecycleStatus.unresolved:
        return "도착 여부를 확인하지 못했어요";
      // 아래 진행 중 상태는 terminal이 아니므로 이 함수가 호출되지 않는다.
      // default 대신 명시적으로 나열해, enum에 값이 추가되면 컴파일러가
      // 이 switch를 잡도록 하고 조용한 빈 문자열 반환을 방지한다.
      case EventLifecycleStatus.planned:
      case EventLifecycleStatus.notified:
      case EventLifecycleStatus.preparing:
      case EventLifecycleStatus.enroute:
        return "";
    }
  }

  double get _fillFraction {
    if (isTerminal) return 1;
    final total = plan.targetArriveAt.difference(plan.prepStartAt).inSeconds;
    if (total <= 0) return 0;
    final elapsed = DateTime.now().difference(plan.prepStartAt).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  static final _timeFmt = _TimeFormatter();

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: EnsomColors.panel,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "시간 계획",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: .9,
              color: Colors.white.withValues(alpha: .4),
            ),
          ),
          const SizedBox(height: 9),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -.2,
              ),
              children: [TextSpan(text: _headline)],
            ),
          ),
          if (!plan.feasible && !isTerminal) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: EnsomColors.caution,
                ),
                const SizedBox(width: 6),
                const Text(
                  "시간이 충분하지 않을 수 있어요",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: EnsomColors.caution,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: _fillFraction,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: EnsomColors.lime,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                for (var i = 0; i < 3; i++)
                  Align(
                    alignment: Alignment(-1 + i * 1.0, 0),
                    child: _Node(active: i == active),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              _TimeCol(
                label: "준비 시작",
                time: plan.prepStartAt,
                active: active == 0,
              ),
              _TimeCol(
                label: "출발",
                time: plan.recommendedDepartAt,
                active: active == 1,
              ),
              _TimeCol(
                label: "도착",
                time: plan.targetArriveAt,
                active: active == 2,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 11 : 9,
      height: active ? 11 : 9,
      decoration: BoxDecoration(
        color: active ? EnsomColors.lime : Colors.white.withValues(alpha: .28),
        shape: BoxShape.circle,
        boxShadow: active
            ? [
                BoxShadow(
                  color: EnsomColors.lime.withValues(alpha: .16),
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }
}

class _TimeCol extends StatelessWidget {
  const _TimeCol({
    required this.label,
    required this.time,
    required this.active,
  });

  final String label;
  final DateTime time;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: .3,
              color: active
                  ? EnsomColors.lime
                  : Colors.white.withValues(alpha: .42),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _TimePlanPanel._timeFmt.format(time),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -.4,
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: .62),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeFormatter {
  String format(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, "0");
    final m = local.minute.toString().padLeft(2, "0");
    return "$h:$m";
  }
}

/// 목업 "계산 근거" — 총합 한 줄만 기본으로 보여주고, "자세히"를
/// 누르면 카테고리별 분(min) 값으로 펼쳐진다.
class _BreakdownCard extends StatefulWidget {
  const _BreakdownCard({required this.breakdown});

  final PlanBreakdown breakdown;

  @override
  State<_BreakdownCard> createState() => _BreakdownCardState();
}

class _BreakdownCardState extends State<_BreakdownCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.breakdown;
    final total =
        b.estimatedPrepMinutes +
        b.extraPrepMinutes +
        b.personalRoutineMinutes +
        b.travelMinutes +
        b.trafficBufferMinutes +
        b.arrivalBufferMinutes;
    final rows = [
      ("개인 준비", b.estimatedPrepMinutes),
      ("추가 준비", b.extraPrepMinutes),
      ("루틴", b.personalRoutineMinutes),
      ("이동", b.travelMinutes),
      ("교통 버퍼", b.trafficBufferMinutes),
      ("도착 여유", b.arrivalBufferMinutes),
    ].where((r) => r.$2 != 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "계산 근거",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -.2,
                color: EnsomColors.ink,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Text(
                      _expanded ? "접기" : "자세히",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: EnsomColors.inkFaint,
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? .5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
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
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
          decoration: BoxDecoration(
            color: EnsomColors.surface1,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: EnsomColors.hairline),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "총 준비·이동",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: EnsomColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      "$total분",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.2,
                        color: EnsomColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (_expanded)
                for (var i = 0; i < rows.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: EnsomColors.hairline),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            rows[i].$1,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: EnsomColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          "${rows[i].$2}분",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.2,
                            color: EnsomColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteSummaryCard extends ConsumerWidget {
  const _RouteSummaryCard({required this.plan, required this.eventId});

  final Plan plan;
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final travelMin = plan.breakdown.travelMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "경로",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: -.2,
            color: EnsomColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: EnsomColors.surface1,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: EnsomColors.hairline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "이동 $travelMin분",
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                    color: EnsomColors.ink,
                  ),
                ),
              ),
              Material(
                color: EnsomColors.cta,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () async {
                    final changed = await showModalBottomSheet<bool>(
                      context: context,
                      builder: (_) => RouteChangeSheet(
                        planId: plan.planId,
                        eventId: eventId,
                      ),
                    );
                    if (changed == true)
                      ref.invalidate(planControllerProvider(eventId));
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text(
                      "변경",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// S-12 → S-11. 장소 필요 여부가 미정(undecided)인 일정에만 나온다.
///
/// 캘린더가 만든 미해결 질문을 찾아 시트를 연다. 질문이 없으면(사용자가 직접
/// 만든 미정 일정) 아무것도 그리지 않는다 — 답할 대상이 없는데 물으면
/// 서버가 REVIEW_NOT_FOUND로 되돌린다.
class _ClassificationPrompt extends ConsumerWidget {
  const _ClassificationPrompt({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (event.locationState != LocationState.undecided) {
      return const SizedBox.shrink();
    }
    // 이 일정의 시작 시각을 포함하는 하루를 조회 범위로 잡는다.
    final day = DateTime(
      event.startsAt.year,
      event.startsAt.month,
      event.startsAt.day,
    );
    final reviews = ref
        .watch(
          pendingReviewsProvider(
            EventRange(from: day, to: day.add(const Duration(days: 1))),
          ),
        )
        .value;
    final review = reviews
        ?.where((r) => r.eventId == event.eventId)
        .firstOrNull;
    if (review == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showClassificationReviewSheet(context, review),
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
                const Expanded(
                  child: Text(
                    "이 일정에 이동이 필요한지 알려주세요",
                    style: TextStyle(
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
