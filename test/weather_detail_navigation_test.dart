import "package:ensom/models/environment_data.dart";
import "package:ensom/providers/environment_provider.dart";
import "package:ensom/screens/home/weather_detail_screen.dart";
import "package:ensom/screens/home/widgets/weather_widget.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";

/// ensom_prototype.html의 `.weather` 탭 → `openWeather()`(전체화면 상세
/// 패널) 동작을 검증한다. 예전엔 탭하면 카드 안에서 로컬 상태로만
/// PM25·자외선을 펼쳤을 뿐 실제 상세 화면으로 이동하지 않았다.
Future<void> _pumpHome(WidgetTester tester, EnvironmentData? data) async {
  final router = GoRouter(
    initialLocation: "/home",
    routes: [
      GoRoute(
        path: "/home",
        builder: (c, s) => const Scaffold(body: WeatherWidget()),
      ),
      GoRoute(
        path: "/weather",
        builder: (c, s) => const WeatherDetailScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [environmentProvider.overrideWith((ref) async => data)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("날씨 카드를 탭하면 날씨 상세 화면으로 이동한다", (tester) async {
    await _pumpHome(
      tester,
      const EnvironmentData(
        temperature: 31,
        sky: "부분적으로 흐림",
        pm10Grade: "보통",
        pm25Grade: "나쁨",
        uvIndex: 9,
      ),
    );

    expect(find.byType(WeatherDetailScreen), findsNothing);

    await tester.tap(find.text("31°"));
    await tester.pumpAndSettle();

    expect(find.byType(WeatherDetailScreen), findsOneWidget);
    // 실제 BE 응답(EnvironmentResponse)에 있는 5개 필드만 보여준다.
    expect(find.text("부분적으로 흐림"), findsOneWidget);
    expect(find.text("지수 9"), findsOneWidget);
    expect(find.text("보통"), findsOneWidget);
    expect(find.text("나쁨"), findsOneWidget);
  });

  testWidgets("날씨 정보가 없으면(대표 장소 미등록) 카드 자체를 숨긴다", (tester) async {
    await _pumpHome(tester, null);

    expect(find.byType(GestureDetector), findsNothing);
  });
}
