/// BE `PendingEventReviewResponse` — GET /v1/events/reviews/pending.
///
/// 캘린더 동기화가 만든 "이 일정에 장소가 필요한가요?" 질문 중 아직 답하지 않은 것.
/// 제목 원문은 24시간 뒤 폐기되므로(§3 S-11) 여기에 담기지 않는다.
class PendingEventReview {
  const PendingEventReview({
    required this.reviewId,
    required this.eventId,
    required this.startsAt,
    required this.questionType,
    this.suggestedValue,
    this.classificationConfidence,
    required this.askedAt,
  });

  factory PendingEventReview.fromJson(Map<String, dynamic> json) =>
      PendingEventReview(
        reviewId: json["reviewId"] as String,
        eventId: json["eventId"] as String,
        startsAt: DateTime.parse(json["startsAt"] as String),
        questionType: json["questionType"] as String,
        suggestedValue: json["suggestedValue"] as String?,
        classificationConfidence: (json["classificationConfidence"] as num?)
            ?.toDouble(),
        askedAt: DateTime.parse(json["askedAt"] as String),
      );

  final String reviewId;
  final String eventId;
  final DateTime startsAt;

  /// 현재는 is_online 하나뿐이다. BE가 다른 값은 422로 거절한다.
  final String questionType;

  final String? suggestedValue;
  final double? classificationConfidence;
  final DateTime askedAt;
}

/// S-11의 세 선택지. "잘 모르겠어요"도 서버에 보내는 답변이다 — 보내지 않으면
/// 질문이 남아 다음에 또 묻게 되고, 그건 §13 "재질문 금지"에 어긋난다.
enum ClassificationAnswer {
  offline("offline"),
  online("online"),
  unknown("unknown");

  const ClassificationAnswer(this.wireValue);

  final String wireValue;
}
