import "package:ensom/models/pending_event_review.dart";
import "package:flutter_test/flutter_test.dart";

/// S-11의 핵심 규칙은 "1회 응답 후 재질문 없음"이다. "잘 모르겠어요"가 서버로
/// 가지 않으면 질문이 미답변으로 남아 다음 목록에서 또 뜬다.
void main() {
  test("세 선택지 모두 서버에 보낼 값이 있다", () {
    expect(ClassificationAnswer.offline.wireValue, "offline");
    expect(ClassificationAnswer.online.wireValue, "online");
    // BE EventService가 받는 값. 넘기지 않는 선택지는 없다.
    expect(ClassificationAnswer.unknown.wireValue, "unknown");
    expect(ClassificationAnswer.values, hasLength(3));
  });

  test("미해결 질문을 서버 필드명 그대로 읽는다", () {
    final review = PendingEventReview.fromJson({
      "reviewId": "r1",
      "eventId": "e1",
      "startsAt": "2026-08-21T01:00:00Z",
      "questionType": "is_online",
      "suggestedValue": "online",
      "classificationConfidence": 0.42,
      "askedAt": "2026-08-20T01:00:00Z",
    });

    expect(review.reviewId, "r1");
    expect(review.eventId, "e1");
    expect(review.questionType, "is_online");
    expect(review.classificationConfidence, closeTo(0.42, 0.0001));
  });

  test("제목이 폐기된 질문도 읽을 수 있다", () {
    // 24시간이 지나면 서버가 제목 원문을 폐기하고 질문만 남긴다(§3 S-11).
    // suggestedValue·confidence가 없어도 파싱이 깨지면 안 된다.
    final review = PendingEventReview.fromJson({
      "reviewId": "r1",
      "eventId": "e1",
      "startsAt": "2026-08-21T01:00:00Z",
      "questionType": "is_online",
      "suggestedValue": null,
      "classificationConfidence": null,
      "askedAt": "2026-08-20T01:00:00Z",
    });

    expect(review.suggestedValue, isNull);
    expect(review.classificationConfidence, isNull);
    expect(review.reviewId, "r1");
  });
}
