import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:ensom/screens/home/widgets/home_empty_state.dart";

void main() {
  testWidgets("홈 빈 상태는 프로토타입 문구와 두 CTA를 보여준다", (tester) async {
    final router = GoRouter(
      initialLocation: "/",
      routes: [
        GoRoute(
          path: "/",
          builder: (_, _) => const Scaffold(body: HomeEmptyState()),
        ),
        GoRoute(
          path: "/calendar/new",
          builder: (_, _) => const Scaffold(body: Text("일정 등록")),
        ),
        GoRoute(
          path: "/map",
          builder: (_, _) => const Scaffold(body: Text("지도")),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.text("관리할 다음 일정이 없어요"), findsOneWidget);
    expect(find.text("일정을 추가하면 준비 시작 시각을 알려드릴게요"), findsOneWidget);
    expect(find.text("일정 만들기"), findsOneWidget);
    expect(find.text("지도에서 찾기"), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text("지도에서 찾기"));
    await tester.pumpAndSettle();
    expect(find.text("지도"), findsOneWidget);
  });
}
