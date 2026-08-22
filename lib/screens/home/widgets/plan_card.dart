import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../../../models/plan.dart";
import "../../../models/today_plan.dart";
import "../../../theme/ensom_colors.dart";
import "../../../widgets/ensom/ensom_pill_button.dart";
import "reason_section.dart";
import "checklist_section.dart";
import "wellness_actions_section.dart";
import "plan_change_banner.dart";

/// HOME-01/02 · S-06 히어로 카드. 화면연결명세서 §3 "홈 카드 상태 6종"을
/// 반영한다. 상태는 GET /plans/today가 내려준 값을 그대로 쓴다 — §7.2가
/// "클라이언트가 시각을 비교해 상태를 계산하지 않는다"고 못박고 있고, 기기
/// 시계·타임존이 틀어지면 상태가 서버와 어긋나기 때문이다.
/// wrap은 카드 전체를 오늘 요약으로 대체하므로 여기서 다루지 않는다.

class _HeroContent {
  const _HeroContent({
    required this.badgeLabel,
    required this.caution,
    required this.headline,
    required this.bigNumber,
    required this.sub,
    required this.ctaLabel,
    required this.onCta,
  });

  final String badgeLabel;
  final bool caution;
  final String headline;
  final String? bigNumber;
  final String sub;
  final String ctaLabel;
  final VoidCallback onCta;
}

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.eventTitle,
    required this.state,
    required this.plan,
    this.previousPlan,
    this.onTap,
    required this.onPrepStart,
    required this.onPrepFinished,
    required this.onDeparted,
    this.onArrived,
    required this.onSnooze,
    required this.onSkip,
    required this.onSelectRoute,
    required this.onToggleChecklistItem,
    required this.onResolveWellnessAction,
  });

  final String eventTitle;

  /// 서버가 판정한 히어로 상태(§7.2).
  final HomeCardState state;

  final Plan plan;
  final Plan? previousPlan;
  final VoidCallback? onTap;
  final VoidCallback onPrepStart;
  final VoidCallback onPrepFinished;
  final VoidCallback onDeparted;
  // 지오펜스가 도착을 자동 확정하지 못했을 때(무신호·권한 거부)의
  // 수동 폴백(TRD §9.3). enroute·unresolved 상태에서만 노출한다.
  final VoidCallback? onArrived;
  final VoidCallback onSnooze;
  final VoidCallback onSkip;
  final VoidCallback onSelectRoute;
  final void Function(ChecklistItem item, bool completed) onToggleChecklistItem;
  final void Function(
    WellnessAction action,
    WellnessActionCompletionStatus status,
  )
  onResolveWellnessAction;

  static final _timeFmt = DateFormat("a h:mm", "ko_KR");

  bool get _isTerminal => const {
    EventLifecycleStatus.arrived,
    EventLifecycleStatus.closed,
    EventLifecycleStatus.skipped,
    EventLifecycleStatus.cancelled,
    EventLifecycleStatus.unresolved,
  }.contains(plan.eventStatus);

  String get _terminalMessage {
    switch (plan.eventStatus) {
      case EventLifecycleStatus.arrived:
        return "도착했어요.";
      case EventLifecycleStatus.closed:
        return "일정이 마무리됐어요.";
      case EventLifecycleStatus.skipped:
        return "이 일정은 건너뛰었어요.";
      case EventLifecycleStatus.cancelled:
        return "이 일정은 취소됐어요.";
      case EventLifecycleStatus.unresolved:
        return "도착 여부를 확인하지 못했어요.";
      default:
        return "";
    }
  }

  _HeroContent _content(HomeCardState band) {
    switch (band) {
      case HomeCardState.wrap:
      case HomeCardState.ease:
        return _HeroContent(
          badgeLabel: "여유",
          caution: false,
          headline: "아직 여유가 있어요.",
          bigNumber: null,
          sub: "${_timeFmt.format(plan.prepStartAt)}부터 준비하면 충분합니다.",
          // 목업 카피는 "준비 알림 받기"이지만 별도 알림 옵트인 액션이
          // 없어 항상 쓸 수 있는 경로 확인으로 연결한다.
          ctaLabel: "경로 확인",
          onCta: onSelectRoute,
        );
      case HomeCardState.start:
        final mins = plan.prepStartAt.difference(DateTime.now()).inMinutes;
        return _HeroContent(
          badgeLabel: "준비 시작",
          caution: false,
          headline: "준비를 시작하세요",
          bigNumber: mins > 0 ? "$mins분" : null,
          sub:
              "${_timeFmt.format(plan.recommendedDepartAt)}에 출발하면 제시간에 도착할 수 있어요.",
          ctaLabel: "준비 시작",
          onCta: onPrepStart,
        );
      case HomeCardState.depart:
        final mins = plan.recommendedDepartAt
            .difference(DateTime.now())
            .inMinutes;
        return _HeroContent(
          badgeLabel: "출발 임박",
          caution: false,
          headline: "출발하세요",
          bigNumber: mins > 0 ? "$mins분" : null,
          sub: "현재 경로로 ${_timeFmt.format(plan.targetArriveAt)} 도착 예정입니다.",
          ctaLabel: "출발했어요",
          onCta: onDeparted,
        );
      case HomeCardState.rush:
        return _HeroContent(
          badgeLabel: "촉박",
          caution: true,
          headline: "지금 출발하는 것이 좋아요.",
          bigNumber: null,
          sub: "가장 빠른 기본 경로를 다시 확인했어요.",
          ctaLabel: "경로 확인",
          onCta: onSelectRoute,
        );
      case HomeCardState.wellness:
        return _HeroContent(
          badgeLabel: "웰니스",
          caution: false,
          headline: "오늘 야외 이동이 길어요.",
          bigNumber: null,
          sub: "출발 전 선크림과 물을 확인해 주세요.",
          ctaLabel: "준비 항목 확인",
          onCta: onTap ?? onSelectRoute,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlanChangeBanner(currentPlan: plan, previousPlan: previousPlan),
        _Hero(
          eventTitle: eventTitle,
          onTap: onTap,
          isTerminal: _isTerminal,
          terminalMessage: _terminalMessage,
          content: _isTerminal ? null : _content(state),
        ),
        if (!_isTerminal) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: onPrepFinished,
                child: const Text("준비 완료"),
              ),
              if (onArrived != null &&
                  (plan.eventStatus == EventLifecycleStatus.enroute ||
                      plan.eventStatus == EventLifecycleStatus.unresolved))
                OutlinedButton(
                  onPressed: onArrived,
                  child: const Text("도착했어요"),
                ),
              OutlinedButton(onPressed: onSnooze, child: const Text("5분 뒤 알림")),
              TextButton(onPressed: onSkip, child: const Text("이번 일정 제외")),
            ],
          ),
        ],
        if (plan.degraded.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            "일부 정보를 최신으로 반영하지 못했어요.",
            style: TextStyle(fontSize: 12, color: EnsomColors.caution),
          ),
        ],
        const SizedBox(height: 16),
        ReasonSection(reasons: plan.reasons),
        const SizedBox(height: 16),
        ChecklistSection(
          checklist: plan.checklist,
          onToggle: onToggleChecklistItem,
        ),
        if (plan.wellnessActions.isNotEmpty) ...[
          const SizedBox(height: 16),
          WellnessActionsSection(
            actions: plan.wellnessActions,
            onResolve: onResolveWellnessAction,
          ),
        ],
      ],
    );
  }
}

/// 라임 히어로 카드 본체. 화면연결명세서·ensom_prototype.html의 `.hero`를
/// 그대로 옮겼다 — 배지, 큰 숫자 카운트다운, CTA. 색으로만 긴박도를
/// 표현하지 않도록(§9.2) 촉박 상태만 배지를 caution(amber)으로 바꾸고
/// 나머지는 타이포 크기·정보량으로 구분한다.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.eventTitle,
    required this.onTap,
    required this.isTerminal,
    required this.terminalMessage,
    required this.content,
  });

  final String eventTitle;
  final VoidCallback? onTap;
  final bool isTerminal;
  final String terminalMessage;
  final _HeroContent? content;

  @override
  Widget build(BuildContext context) {
    final c = content;
    return Material(
      color: isTerminal ? EnsomColors.surface1 : EnsomColors.lime,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          decoration: isTerminal
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: EnsomColors.hairline),
                )
              : null,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eventTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isTerminal
                      ? EnsomColors.inkMuted
                      : EnsomColors.ink.withValues(alpha: .72),
                ),
              ),
              const SizedBox(height: 10),
              if (isTerminal) ...[
                Text(
                  terminalMessage,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.4,
                    color: EnsomColors.ink,
                  ),
                ),
              ] else if (c != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: c.caution
                        ? EnsomColors.caution
                        : Colors.white.withValues(alpha: .62),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    c.badgeLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: EnsomColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.8,
                      color: EnsomColors.ink,
                      height: 1.2,
                    ),
                    children: [
                      if (c.bigNumber != null)
                        TextSpan(
                          text: "${c.bigNumber} ",
                          style: const TextStyle(
                            fontSize: 40,
                            letterSpacing: -1.4,
                          ),
                        ),
                      TextSpan(text: c.headline),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  c.sub,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: EnsomColors.ink.withValues(alpha: .72),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: EnsomPillButton(
                    label: c.ctaLabel,
                    onPressed: c.onCta,
                    expand: false,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
