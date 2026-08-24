import "package:ensom/models/environment_data.dart";
import "package:ensom/network/api_client.dart";
import "package:ensom/providers/environment_provider.dart";
import "package:ensom/router/app_router.dart";
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

  testWidgets("production route table에 /weather가 WeatherDetailScreen으로 등록돼 있다", (
    tester,
  ) async {
    // 위 테스트들은 이 파일이 직접 만든 GoRouter를 쓰므로, app_router.dart의
    // 실제 route가 빠지거나 경로가 오타나도 잡아내지 못한다. buildAppRoutes는
    // appRouterProvider가 쓰는 것과 동일한 route 목록이라, 여기서 직접 만든
    // GoRouter가 아니라 그 목록으로 GoRouter를 띄워 /weather가 실제로
    // WeatherDetailScreen을 그리는지 확인한다.
    // buildAppRoutes(ref)는 route 생성 시점에 Ref를 캡처만 해 두고(온보딩
    // 프라이밍 화면의 onAllow/onSkip 콜백 안에서만 나중에 쓰인다), 목록을
    // 만드는 동안에는 다른 provider를 구독하지 않는다 — 그래서 auth 상태
    // 목킹 없이도 안전하게 호출할 수 있다. 여기서 얻은 routes는 이미
    // 확정된 값이라, 뽑아내는 데 쓴 컨테이너는 바로 버려도 된다.
    final probeContainer = ProviderContainer();
    late final List<RouteBase> routes;
    final probe = Provider<void>((ref) => routes = buildAppRoutes(ref));
    probeContainer.read(probe);
    probeContainer.dispose();

    final router = GoRouter(initialLocation: "/weather", routes: routes);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentProvider.overrideWith(
            (ref) async => const EnvironmentData(temperature: 20, sky: "맑음"),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WeatherDetailScreen), findsOneWidget);
  });

  testWidgets("환경 조회가 실패하면 대표 장소 안내 대신 재시도 버튼을 보여준다", (tester) async {
    var callCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentProvider.overrideWith((ref) async {
            callCount++;
            throw ApiException(
              code: "ENVIRONMENT_UNAVAILABLE",
              message: "test",
            );
          }),
        ],
        child: const MaterialApp(home: WeatherDetailScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // ENVIRONMENT_UNAVAILABLE도 404지만 "대표 장소 등록" 안내를 띄우면
    // 안 된다 — 대표 장소는 이미 있고 조회 자체가 실패한 경우다.
    expect(find.text("자주 가는 장소를 등록하면 날씨 정보를 보여드려요."), findsNothing);
    expect(find.text("날씨 정보를 불러오지 못했어요."), findsOneWidget);

    final beforeRetry = callCount;
    await tester.tap(find.text("다시 시도"));
    await tester.pumpAndSettle();

    // "다시 시도"가 ref.invalidate(environmentProvider)로 재요청을 트리거한다.
    expect(callCount, greaterThan(beforeRetry));
  });
}
