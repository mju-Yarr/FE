import "package:ensom/models/event.dart";
import "package:ensom/models/pending_event_review.dart";
import "package:ensom/network/api_client.dart";
import "package:ensom/repository/ensom_repository.dart";
import "package:ensom/repository/providers.dart";
import "package:ensom/screens/calendar/widgets/classification_review_sheet.dart";
import "package:ensom/widgets/ensom/ensom_pill_button.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:intl/date_symbol_data_local.dart";

/// S-11 시트가 실제로 서버를 부르는지 확인한다. 배선만 해 두고 화면에서
/// 호출되지 않던 것이 이 기능의 원래 문제였다.
class _FakeRepo implements EnsomRepository {
  final calls = <({String eventId, String? reviewId, String answer})>[];
  ApiException? failWith;

  @override
  Future<void> reviewEventClassification(
    String eventId,
    EventClassificationReview review, {
    String? reviewId,
  }) async {
    calls.add((
      eventId: eventId,
      reviewId: reviewId,
      answer: review.userAnswer,
    ));
    if (failWith != null) throw failWith!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

final _review = PendingEventReview(
  reviewId: "r1",
  eventId: "e1",
  startsAt: DateTime.utc(2026, 8, 21, 1),
  questionType: "is_online",
  askedAt: DateTime.utc(2026, 8, 20, 1),
);

Future<void> _openSheet(WidgetTester tester, _FakeRepo repo) async {
  tester.view.physicalSize = const Size(834, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [ensomRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showClassificationReviewSheet(context, _review),
              child: const Text("열기"),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text("열기"));
  await tester.pumpAndSettle();
}

Future<void> _tapAnswer(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(EnsomPillButton, label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting("ko_KR", null));

  testWidgets("세 선택지가 모두 보인다", (tester) async {
    await _openSheet(tester, _FakeRepo());

    expect(find.text("네, 장소가 있어요"), findsOneWidget);
    expect(find.text("아니요, 온라인·재택이에요"), findsOneWidget);
    expect(find.text("잘 모르겠어요"), findsOneWidget);
  });

  testWidgets("장소 있음은 offline으로 보내고 reviewId를 함께 넘긴다", (tester) async {
    final repo = _FakeRepo();
    await _openSheet(tester, repo);
    await _tapAnswer(tester, "네, 장소가 있어요");

    expect(repo.calls, hasLength(1));
    expect(repo.calls.single.answer, "offline");
    expect(repo.calls.single.eventId, "e1");
    // reviewId가 없으면 BE의 REVIEW_STALE·REVIEW_ALREADY_CLOSED 방어가 무력화된다.
    expect(repo.calls.single.reviewId, "r1");
  });

  testWidgets("온라인은 online으로 보낸다", (tester) async {
    final repo = _FakeRepo();
    await _openSheet(tester, repo);
    await _tapAnswer(tester, "아니요, 온라인·재택이에요");

    expect(repo.calls.single.answer, "online");
  });

  testWidgets("잘 모르겠어요도 서버로 보낸다", (tester) async {
    // §13 "재질문 금지" — 안 보내면 질문이 남아 다음에 또 뜬다.
    final repo = _FakeRepo();
    await _openSheet(tester, repo);
    await _tapAnswer(tester, "잘 모르겠어요");

    expect(repo.calls, hasLength(1));
    expect(repo.calls.single.answer, "unknown");
    expect(repo.calls.single.reviewId, "r1");
  });

  testWidgets("답하면 시트가 닫힌다", (tester) async {
    final repo = _FakeRepo();
    await _openSheet(tester, repo);
    await _tapAnswer(tester, "잘 모르겠어요");

    expect(find.text("잘 모르겠어요"), findsNothing);
  });

  testWidgets("그냥 닫으면 아무것도 보내지 않는다", (tester) async {
    // §3 "뒤로 → 시트 닫힘. 상태는 미해결로 유지". 답을 미룬 것이지
    // 모른다고 답한 것이 아니다.
    final repo = _FakeRepo();
    await _openSheet(tester, repo);

    await tester.tapAt(const Offset(10, 10)); // 스크림 탭
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
    expect(find.text("잘 모르겠어요"), findsNothing);
  });

  testWidgets("이미 닫힌 질문은 안내를 보여주고 시트를 유지한다", (tester) async {
    final repo = _FakeRepo()
      ..failWith = ApiException(
        code: "REVIEW_ALREADY_CLOSED",
        message: "이미 답변이 완료된 분류 확인 질문입니다.",
      );
    await _openSheet(tester, repo);
    await _tapAnswer(tester, "네, 장소가 있어요");

    expect(find.text("이미 답변한 질문이에요."), findsOneWidget);
  });

  testWidgets("실패 후 다시 시도할 수 있다", (tester) async {
    // _submitting이 풀리지 않으면 버튼이 영원히 비활성으로 남는다.
    final repo = _FakeRepo()
      ..failWith = ApiException(
        code: "NETWORK_ERROR",
        message: "네트워크에 연결할 수 없어요.",
        retryable: true,
      );
    await _openSheet(tester, repo);
    await _tapAnswer(tester, "네, 장소가 있어요");
    expect(find.text("네트워크에 연결할 수 없어요."), findsOneWidget);

    repo.failWith = null;
    await _tapAnswer(tester, "네, 장소가 있어요");

    expect(repo.calls, hasLength(2));
    expect(find.text("잘 모르겠어요"), findsNothing);
  });
}
