import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:uuid/uuid.dart";
import "../../core/coachmark_service.dart";
import "../../models/action_log.dart";
import "../../models/plan.dart";
import "../../models/today_plan.dart";
import "../../providers/home_providers.dart";
import "../../providers/local_notification_providers.dart";
import "../../providers/bootstrap_provider.dart";
import "../../providers/offline_queue_providers.dart";
import "../../providers/system_state_provider.dart";
import "../../repository/providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/coachmark_overlay.dart";
import "../../widgets/ensom/ensom_error_banner.dart";
import "../../widgets/ensom/ensom_pill_button.dart";
import "../../widgets/ensom/ensom_skeleton.dart";
import "../../widgets/ensom/ensom_wordmark.dart";
import "../../widgets/permission_degraded_banner.dart";
import "../../widgets/prep_item_add_sheet.dart";
import "../../models/event.dart";
import "widgets/arrival_result_card.dart";
import "widgets/empty_hero_card.dart";
import "widgets/plan_card.dart";
import "widgets/stacked_event_cards.dart";
import "widgets/today_wrap_card.dart";
import "widgets/weather_widget.dart";

Future<void> scheduleHomePlanNotifications({
  required EventNotificationCoordinator coordinator,
  required Plan plan,
  required String eventDisplayName,
}) {
  return coordinator.reschedule(
    eventId: plan.eventId,
    revisionNo: plan.revisionNo,
    prepStartAt: plan.prepStartAt,
    recommendedDepartAt: plan.recommendedDepartAt,
    eventDisplayName: eventDisplayName,
  );
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int? _lastScheduledRevision;
  bool _coachmarkChecked = false;

  Future<void> _maybeShowCoachmark() async {
    final shouldShow = await CoachmarkService.instance.shouldShowCoachmark();
    if (!shouldShow || !mounted) return;
    _showCoachmarkOverlay();
  }

  void _showCoachmarkOverlay() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => CoachmarkOverlay(
        onDismiss: () {
          entry.remove();
          CoachmarkService.instance.markCoachmarkShown();
        },
      ),
    );
    overlay.insert(entry);
  }

  Future<void> _enqueueAndMaybeRefresh(
    String eventId,
    String planId,
    ActionType type,
  ) async {
    final queue = ref.read(offlineActionQueueServiceProvider);
    final sent = await queue.enqueue(
      planId: planId,
      actionType: type,
      actionSource: ActionSource.user,
    );

    if (sent) {
      ref.read(planControllerProvider(eventId).notifier).retry();
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("오프라인 상태예요. 연결되면 자동으로 반영돼요.")));
  }

  // 지오펜스가 도착을 확정하지 못했을 때(무신호·권한 거부)의 수동 폴백
  // (TRD §9.3). 배치 큐가 아니라 즉시 호출한다 -- 지오펜스 경로도 큐를
  // 거치지 않고 바로 reportArrival을 부르므로 동일한 방식을 쓴다.
  Future<void> _reportArrived(String eventId, String planId) async {
    try {
      await ref
          .read(ensomRepositoryProvider)
          .reportArrival(
            eventId,
            planId,
            clientEventId: const Uuid().v4(),
            source: ActionSource.user,
          );
      ref.read(planControllerProvider(eventId).notifier).retry();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("처리하지 못했어요. 다시 시도해주세요.")));
    }
  }

  // ensom_prototype.html HM-01 [+ 추가] → 준비 항목 추가 시트(PREP-01).
  // createPrepItem은 사용자 단위 규칙이라 특정 이벤트에 매이지 않지만,
  // 저장 후에는 오늘의 히어로 계획을 다시 불러와 새 규칙이 반영됐는지
  // 보여준다.
  Future<void> _openPrepSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PrepItemAddSheet(),
    );
    if (added != true || !mounted) return;
    final heroEventId = ref.read(todayPlanProvider).value?.hero?.event.eventId;
    if (heroEventId != null) {
      ref.invalidate(planControllerProvider(heroEventId));
    }
    ref.invalidate(todayPlanProvider);
  }

  void _scheduleLocalNotifications(Plan plan, String eventDisplayName) {
    if (_lastScheduledRevision == plan.revisionNo) return;
    _lastScheduledRevision = plan.revisionNo;
    scheduleHomePlanNotifications(
      coordinator: ref.read(eventNotificationCoordinatorProvider),
      plan: plan,
      eventDisplayName: eventDisplayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(offlineQueueFlushProvider);
    final todayAsync = ref.watch(todayPlanProvider);

    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const EnsomWordmark(fontSize: 15),
                  Row(
                    children: [
                      _IconAction(
                        icon: Icons.add,
                        tooltip: "준비 항목 추가",
                        onTap: _openPrepSheet,
                      ),
                      const SizedBox(width: 6),
                      _IconAction(
                        icon: Icons.notifications_none,
                        tooltip: "오늘의 알림",
                        onTap: () => context.push("/notifications/today"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(todayAsync)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AsyncValue<TodayPlan> todayAsync) {
    final nickname = ref.watch(bootstrapProvider).value?.user.nickname;
    Widget overview(int count) =>
        _HomeOverviewHeader(nickname: nickname, eventCount: count);
    return todayAsync.when(
      // §11 로딩은 스켈레톤. 스피너는 스플래시 워드마크 링에만 허용된다.
      loading: () => ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        children: const [
          EnsomSkeleton.card(height: 104),
          SizedBox(height: 16),
          EnsomSkeleton.card(height: 260),
          SizedBox(height: 12),
          EnsomSkeleton.card(height: 72),
        ],
      ),
      error: (err, st) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "불러오지 못했어요.",
              style: TextStyle(color: EnsomColors.inkMuted),
            ),
            const SizedBox(height: 14),
            EnsomPillButton(
              label: "다시 시도",
              expand: false,
              onPressed: () => ref.invalidate(todayPlanProvider),
            ),
          ],
        ),
      ),
      data: (today) {
        // §3 S-06 — 일정이 0건이면 히어로 카드 자리에 빈 상태가 그대로
        // 들어간다(ensom_prototype.html `.hero.empty` — 별도 카드 섹션이
        // 아니다. 날씨 위젯도 계속 보인다).
        if (today.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            children: [
              overview(0),
              const SizedBox(height: 20),
              const EmptyHeroCard(),
            ],
          );
        }

        // §3 S-06 — wrap은 별도 화면이 아니라 히어로 카드를 대체하는 상태다.
        // 겹친 카드를 두지 않고 오늘 요약 3칸을 보여준다.
        if (today.homeState == HomeCardState.wrap) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            children: [
              overview(today.cards.length),
              const SizedBox(height: 20),
              _DegradedBanner(reasons: today.degraded),
              TodayWrapCard(
                summary: today.wrapSummary,
                onTap: () => context.push("/summary/daily"),
              ),
            ],
          );
        }

        final hero = today.hero!;
        // 이동 계획이 없는 일정(온라인 미팅 등)이 맨 앞일 수 있다. 이때
        // planController를 부르면 계획이 없어 오류 화면이 뜨므로, 계획 없는
        // 목록 형태로 그린다.
        if (hero.plan == null) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            children: [
              overview(today.cards.length),
              const SizedBox(height: 20),
              _DegradedBanner(reasons: today.degraded),
              StackedEventCards(
                cards: today.cards,
                totalCount: today.cards.length,
                onTapCard: (card) =>
                    context.push("/events/${card.event.eventId}"),
                onSeeAll: () => context.go("/calendar"),
              ),
            ],
          );
        }

        final event = hero.event;
        final planState = ref.watch(planControllerProvider(event.eventId));
        final controller = ref.read(
          planControllerProvider(event.eventId).notifier,
        );

        // 코치마크: 데이터 로딩 완료 + 일정 있을 때만 1회 표시
        if (!_coachmarkChecked) {
          _coachmarkChecked = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _maybeShowCoachmark(),
          );
        }

        return planState.when(
          loading: () => ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            children: const [
              EnsomSkeleton.card(height: 104),
              SizedBox(height: 16),
              EnsomSkeleton.card(height: 260),
            ],
          ),
          error: (err, st) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "계획을 불러오지 못했어요.",
                  style: TextStyle(color: EnsomColors.inkMuted),
                ),
                const SizedBox(height: 14),
                EnsomPillButton(
                  label: "다시 시도",
                  expand: false,
                  onPressed: controller.retry,
                ),
              ],
            ),
          ),
          data: (plan) {
            _scheduleLocalNotifications(plan, event.displayName);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                overview(today.cards.length),
                const SizedBox(height: 20),
                const PermissionDegradedBanner(
                  type: DegradedPermissionType.notification,
                ),
                const PermissionDegradedBanner(
                  type: DegradedPermissionType.location,
                ),
                // §1.5 부분 실패는 전면 차단이 아니라 인라인 배너로만 알린다.
                _DegradedBanner(reasons: today.degraded),
                PlanCard(
                  eventTitle: event.displayName,
                  eventStartsAt: event.startsAt,
                  eventPlace: event.locationState == LocationState.notRequired
                      ? null
                      : event.destinationName,
                  state: today.homeState,
                  plan: plan,
                  previousPlan: controller.previousPlan,
                  stacked: today.stacked,
                  totalCount: today.cards.length,
                  onTapStacked: (card) =>
                      context.push("/events/${card.event.eventId}"),
                  onSeeAllStacked: () => context.go("/calendar"),
                  onTap: () => context.push("/events/${event.eventId}"),
                  onPrepStart: () => _enqueueAndMaybeRefresh(
                    event.eventId,
                    plan.planId,
                    ActionType.prepStarted,
                  ),
                  onPrepFinished: () => _enqueueAndMaybeRefresh(
                    event.eventId,
                    plan.planId,
                    ActionType.prepFinished,
                  ),
                  onDeparted: () => _enqueueAndMaybeRefresh(
                    event.eventId,
                    plan.planId,
                    ActionType.departed,
                  ),
                  onArrived: () => _reportArrived(event.eventId, plan.planId),
                  onSnooze: () => _enqueueAndMaybeRefresh(
                    event.eventId,
                    plan.planId,
                    ActionType.snoozed,
                  ),
                  onSkip: () => _enqueueAndMaybeRefresh(
                    event.eventId,
                    plan.planId,
                    ActionType.excluded,
                  ),
                  onSelectRoute: () => context.push(
                    "/plans/${plan.planId}/routes?eventId=${event.eventId}",
                  ),
                  onToggleChecklistItem: (item, completed) async {
                    try {
                      await controller.toggleChecklistItem(item, completed);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("처리하지 못했어요. 다시 시도해주세요.")),
                      );
                    }
                  },
                  onResolveWellnessAction: (action, status) async {
                    try {
                      await controller.resolveWellnessAction(action, status);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("처리하지 못했어요. 다시 시도해주세요.")),
                      );
                    }
                  },
                ),
                // §3 S-06 — 히어로 뒤에 겹치는 오늘의 남은 일정은 이제
                // PlanCard가 직접 그린다(겹쳐 보이는 스택, 위 참고).
                if (plan.eventStatus == EventLifecycleStatus.arrived ||
                    plan.eventStatus == EventLifecycleStatus.closed) ...[
                  const SizedBox(height: 16),
                  ArrivalResultCard(eventId: event.eventId),
                  const SizedBox(height: 12),
                  _DailySummaryRow(onTap: () => context.push("/summary/daily")),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// §1.5 · §11 — 일부 API만 실패한 경우. 전면으로 막지 않고 가진 데이터는
/// 계속 보여주면서 배너로만 알린다.
class _DegradedBanner extends ConsumerWidget {
  const _DegradedBanner({required this.reasons});

  final List<String> reasons;

  static const _messages = {
    "route_unavailable": "경로 정보를 불러오지 못했어요. 예상 시간이 정확하지 않을 수 있어요.",
    "environment_unavailable": "날씨·대기 정보를 불러오지 못했어요.",
    "daily_summary_unavailable": "오늘 요약을 아직 만들지 못했어요.",
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reasons.isEmpty) return const SizedBox.shrink();
    final dismissed = ref.watch(systemStateProvider).dismissedBanners;
    // §11 사용자가 닫은 배너는 그 세션 동안 다시 띄우지 않는다.
    final visible = reasons.where((r) => !dismissed.contains(r)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final reason in visible) ...[
          Row(
            children: [
              Expanded(
                child: EnsomErrorBanner(
                  title: _messages[reason] ?? "일부 정보를 불러오지 못했어요.",
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                color: EnsomColors.inkFaint,
                tooltip: "닫기",
                onPressed: () => ref
                    .read(systemStateProvider.notifier)
                    .dismissBanner(reason),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
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
            child: Icon(icon, size: 16, color: EnsomColors.ink),
          ),
        ),
      ),
    );
  }
}

class _HomeOverviewHeader extends StatelessWidget {
  const _HomeOverviewHeader({this.nickname, required this.eventCount});

  final String? nickname;
  final int eventCount;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return "좋은 아침이에요,";
    if (hour < 18) return "좋은 오후예요,";
    return "좋은 저녁이에요,";
  }

  @override
  Widget build(BuildContext context) {
    final name = nickname?.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$_greeting\n${name == null || name.isEmpty ? "회원" : name} 님",
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.5,
                  height: 1.25,
                  color: EnsomColors.ink,
                ),
              ),
              const SizedBox(height: 5),
              // ensom_prototype.html render(): count===0이면 "오늘
              // 등록된 일정이 없어요", 그 외엔 "오늘 일정 N개" — 날씨
              // 위젯은 0건일 때도 계속 보인다(감춘 적 없다).
              Text(
                eventCount == 0 ? "오늘 등록된 일정이 없어요" : "오늘 일정 $eventCount개",
                style: const TextStyle(
                  fontSize: 12.5,
                  color: EnsomColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const WeatherWidget(),
      ],
    );
  }
}

class _DailySummaryRow extends StatelessWidget {
  const _DailySummaryRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EnsomColors.surface1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
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
                  Icons.nightlight_round_outlined,
                  size: 15,
                  color: EnsomColors.ink,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "오늘의 마무리",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.2,
                        color: EnsomColors.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "하루를 돌아보세요",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: EnsomColors.inkFaint,
                      ),
                    ),
                  ],
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
    );
  }
}
