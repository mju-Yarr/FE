import "dart:convert";

import "package:ensom/network/api_client.dart";
import "package:ensom/providers/auth_providers.dart";
import "package:ensom/screens/profile/account_screen.dart";
import "package:ensom/screens/profile/providers_screen.dart";
import "package:ensom/core/secure_storage_service.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

/// 명세가 명시적으로 못박은 프로필 규칙들. 코드가 조용히 되돌아가기 쉬운 곳이라
/// 화면에 실제로 그려지는 결과로 고정한다.
ApiClient _client(List<Map<String, dynamic>> providers) => ApiClient(
  baseUrl: "https://api.ensom.test/v1",
  secureStorage: _MemorySecureStorage(),
  httpClient: MockClient((request) async {
    if (request.url.path.endsWith("/me/providers")) {
      return http.Response(
        jsonEncode({"data": providers}),
        200,
        headers: {"content-type": "application/json"},
      );
    }
    return http.Response(jsonEncode({"data": {}}), 200);
  }),
);

Future<void> _pump(WidgetTester tester, Widget screen, ApiClient client) async {
  tester.view.physicalSize = const Size(834, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: "/x",
    routes: [
      GoRoute(path: "/x", builder: (c, s) => screen),
      GoRoute(path: "/profile/sessions", builder: (c, s) => const SizedBox()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(client)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("S-24에 로그인 기록 진입이 없다", (tester) async {
    // §3 S-24 조건·예외 · §14 — 로그인 기록은 MVP 범위에서 제외됐다.
    await _pump(tester, const AccountScreen(), _client(const []));

    expect(find.text("로그인 기록"), findsNothing);
    // 나머지 행은 그대로 있어야 한다.
    expect(find.text("이메일 변경"), findsOneWidget);
    expect(find.text("비밀번호 변경"), findsOneWidget);
    expect(find.text("로그인 수단"), findsOneWidget);
    expect(find.text("회원 탈퇴"), findsOneWidget);
  });

  testWidgets("마지막 로그인 수단은 해제 버튼을 숨기지 않고 비활성으로 둔다", (tester) async {
    // §13 "S-27 마지막 로그인 수단 — 해제 버튼 비활성화". 숨기면 왜 못 하는지
    // 알 수 없다(§8).
    await _pump(
      tester,
      const ProvidersScreen(),
      _client(const [
        {"identityId": "i1", "provider": "email", "email": "me@example.com"},
      ]),
    );

    expect(find.text("해제"), findsOneWidget);
    final inkWell = tester.widget<InkWell>(
      find.ancestor(of: find.text("해제"), matching: find.byType(InkWell)).first,
    );
    expect(inkWell.onTap, isNull);
    expect(find.textContaining("마지막 로그인 수단은 해제할 수 없어요"), findsOneWidget);
  });

  testWidgets("수단이 둘이면 해제할 수 있다", (tester) async {
    await _pump(
      tester,
      const ProvidersScreen(),
      _client(const [
        {"identityId": "i1", "provider": "email", "email": "me@example.com"},
        {"identityId": "i2", "provider": "google", "email": "me@gmail.com"},
      ]),
    );

    expect(find.text("해제"), findsNWidgets(2));
    final inkWell = tester.widget<InkWell>(
      find.ancestor(of: find.text("해제"), matching: find.byType(InkWell)).first,
    );
    expect(inkWell.onTap, isNotNull);
    expect(find.textContaining("마지막 로그인 수단은 해제할 수 없어요"), findsNothing);
  });
}

class _MemorySecureStorage extends SecureStorageService {
  @override
  Future<String?> get accessToken async => "access-token";

  @override
  Future<String?> get refreshToken async => "refresh-token";

  @override
  Future<String?> get userId async => "user-1";

  @override
  Future<bool> get hasSession async => true;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {}

  @override
  Future<void> clearSession() async {}
}
