import "package:ensom/core/secure_storage_service.dart";
import "package:ensom/network/api_client.dart";
import "package:ensom/providers/auth_providers.dart";
import "package:ensom/screens/map/map_screen.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  testWidgets("current location marker follows the map bookmark prototype", (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: CurrentLocationMarker())),
      ),
    );

    expect(find.text("현재 위치"), findsOneWidget);
    expect(
      tester.getSize(find.byType(CurrentLocationMarker)),
      const Size(84, 58),
    );

    final decoratedContainers = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(CurrentLocationMarker),
        matching: find.byType(Container),
      ),
    );
    expect(
      decoratedContainers.any(
        (container) => container.constraints?.maxWidth == 36,
      ),
      isTrue,
    );
    expect(
      decoratedContainers.any(
        (container) => container.constraints?.maxWidth == 14,
      ),
      isTrue,
    );
  });

  testWidgets("map draft destination and bookmark preload coexist", (
    tester,
  ) async {
    var bookmarkRequests = 0;
    final apiClient = ApiClient(
      baseUrl: "https://api.ensom.test/v1",
      secureStorage: _MemorySecureStorage(),
      httpClient: MockClient((request) async {
        if (request.url.path == "/v1/me/bookmarks") bookmarkRequests++;
        return http.Response("[]", 200);
      }),
    );

    Widget app(String name, double lat, double lng) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
      child: MaterialApp(
        home: MapScreen(
          initialDestName: name,
          initialDestLat: lat,
          initialDestLng: lng,
        ),
      ),
    );

    await tester.pumpWidget(app("복원 목적지", 37.5665, 126.9780));
    await tester.pump();

    expect(find.text("복원 목적지"), findsWidgets);
    expect(bookmarkRequests, 1);

    await tester.pumpWidget(app("변경 목적지", 37.5700, 126.9900));
    await tester.pump();

    expect(find.text("변경 목적지"), findsWidgets);
    expect(find.text("복원 목적지"), findsNothing);
  });
}

class _MemorySecureStorage extends SecureStorageService {
  @override
  Future<String?> get accessToken async => "access-token";

  @override
  Future<String?> get refreshToken async => "refresh-token";

  @override
  Future<String?> get userId async => "user-id";
}
