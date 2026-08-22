import "daily_wellness_summary.dart";
import "event.dart";
import "plan.dart";

/// S-06 히어로 카드 상태 6종 (명세 §3 S-06).
///
/// §7.2 — "홈 카드 상태는 서버가 내려준다. 클라이언트가 시각을 비교해 상태를
/// 계산하지 않는다." 시계 오차·타임존으로 상태가 어긋나기 때문이다. 남은 시간
/// 카운트다운만 클라이언트가 표시한다.
enum HomeCardState {
  ease("여유"),
  start("준비 시작"),
  depart("출발 임박"),
  rush("촉박"),
  wellness("웰니스"),
  wrap("오늘 마무리");

  const HomeCardState(this.badge);

  /// 배지 문구. 프로토타입 STATES의 badge와 같다.
  final String badge;

  /// §9.2 — 상태를 색으로만 구분하지 않는다. 촉박만 caution 톤을 쓰고
  /// 나머지는 중립 배지에 텍스트로 구분한다.
  bool get isCaution => this == HomeCardState.rush;

  static HomeCardState parse(String? value) {
    return HomeCardState.values.firstWhere(
      (state) => state.name == value,
      // 서버가 모르는 상태를 새로 내려도 홈이 비지 않게 여유로 떨어뜨린다.
      orElse: () => HomeCardState.ease,
    );
  }
}

/// BE `TodayPlanResponse.Card`.
class TodayPlanCard {
  const TodayPlanCard({required this.state, required this.event, this.plan});

  factory TodayPlanCard.fromJson(Map<String, dynamic> json) {
    final plan = json["plan"] as Map<String, dynamic>?;
    return TodayPlanCard(
      state: HomeCardState.parse(json["state"] as String?),
      event: Event.fromJson(json["event"] as Map<String, dynamic>),
      plan: plan == null ? null : Plan.fromJson(plan),
    );
  }

  final HomeCardState state;
  final Event event;

  /// 이동 계획이 없는 일정(locationState=not_required)은 plan이 없다.
  final Plan? plan;
}

/// BE `TodayPlanResponse` — GET /v1/plans/today.
class TodayPlan {
  TodayPlan({
    required this.serverNow,
    required this.date,
    required this.homeState,
    required this.cards,
    this.wrapSummary,
    this.degraded = const [],
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory TodayPlan.fromJson(Map<String, dynamic> json) {
    final wrap = json["wrapSummary"] as Map<String, dynamic>?;
    return TodayPlan(
      serverNow: DateTime.parse(json["serverNow"] as String),
      date: json["date"] as String,
      homeState: HomeCardState.parse(json["homeState"] as String?),
      cards: (json["cards"] as List<dynamic>? ?? const [])
          .map((card) => TodayPlanCard.fromJson(card as Map<String, dynamic>))
          .toList(),
      wrapSummary: wrap == null ? null : DailyWellnessSummary.fromJson(wrap),
      degraded: (json["degraded"] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  /// 서버 기준 시각. 카운트다운을 기기 시계가 아니라 이 값 기준으로 맞춘다.
  final DateTime serverNow;

  /// yyyy-MM-dd, 사용자 타임존 기준의 오늘.
  final String date;

  /// 히어로 카드가 취할 상태.
  final HomeCardState homeState;

  /// 시작 시각 오름차순. 첫 장이 히어로, 나머지가 뒤에 겹치는 카드다.
  final List<TodayPlanCard> cards;

  /// wrap 상태에서만 채워진다(오늘 요약 3칸).
  final DailyWellnessSummary? wrapSummary;

  /// 부분 실패 목록. §1.5에 따라 전면 차단이 아니라 인라인 배너로 알린다.
  final List<String> degraded;

  bool get isEmpty => cards.isEmpty;

  TodayPlanCard? get hero => cards.isEmpty ? null : cards.first;

  /// 히어로 뒤에 겹쳐 보이는 카드들. wrap일 때는 겹치지 않는다(§3 S-06).
  List<TodayPlanCard> get stacked {
    if (cards.length <= 1 || homeState == HomeCardState.wrap) return const [];
    return cards.sublist(1);
  }

  /// 이 응답을 받은 기기 시각. 아래 카운트다운이 경과 시간을 재는 기준점이다.
  final DateTime receivedAt;

  /// 남은 시간. 기기 시계가 틀어져 있어도 서버 시각 기준으로 세도록,
  /// 응답 이후 흐른 시간만 serverNow에 더해서 현재를 추정한다.
  Duration? remainingUntil(DateTime? target) {
    if (target == null) return null;
    final elapsed = DateTime.now().difference(receivedAt);
    return target.difference(serverNow.add(elapsed));
  }
}
