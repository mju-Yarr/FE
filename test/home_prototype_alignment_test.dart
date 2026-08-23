import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:ensom/screens/home/widgets/empty_hero_card.dart";

void main() {
  testWidgets("홈 빈 상태는 ensom_prototype.html의 히어로 자리·문구·두 CTA를 그대로 보여준다", (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: "/",
      routes: [
        GoRoute(
          path: "/",
          builder: (_, _) => const Scaffold(body: EmptyHeroCard()),
        ),
        GoRoute(
          path: "/calendar/new",
          builder: (_, _) => const Scaffold(body: Text("일정 등록")),
        ),
        GoRoute(
          path: "/calendar/connections",
          builder: (_, _) => const Scaffold(body: Text("캘린더 연동")),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.text("관리할 다음 일정이 없어요"), findsOneWidget);
    expect(find.text("일정을 추가하면 준비 시작 시각을 알려드릴게요."), findsOneWidget);
    expect(find.text("일정 만들기"), findsOneWidget);
    expect(find.text("캘린더 연동"), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text("캘린더 연동"));
    await tester.pumpAndSettle();
    expect(find.text("캘린더 연동"), findsOneWidget);
  });
}
