import "dart:convert";

import "package:ensom/core/secure_storage_service.dart";
import "package:ensom/models/notification.dart";
import "package:ensom/models/event.dart";
import "package:ensom/network/api_client.dart";
import "package:ensom/repository/api_ensom_repository.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

class _StubStorage extends SecureStorageService {
  @override
  Future<String?> get accessToken async => "access";

  @override
  Future<String?> get refreshToken async => "refresh";

  @override
  Future<String?> get userId async => "user";

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {}

  @override
  Future<void> clearSession() async {}
}

Future<ApiEnsomRepository> _repository(
  Future<http.Response> Function(http.Request request) handler,
) async {
  final client = ApiClient(
    baseUrl: "https://api.ensom.test/v1",
    secureStorage: _StubStorage(),
    httpClient: MockClient(handler),
  );
  final generation = client.beginSessionTransition();
  await client.saveSession(
    expectedGeneration: generation,
    accessToken: "access",
    refreshToken: "refresh",
    userId: "user",
  );
  return ApiEnsomRepository(client);
}

void main() {
  test("notification response sends the BE reaction contract only", () async {
    http.Request? captured;
    final repository = await _repository((request) async {
      captured = request;
      return http.Response("{}", 200);
    });

    await repository.respondToNotification(
      "notification-1",
      NotificationReaction.started,
    );

    expect(captured, isNotNull);
    expect(captured!.method, "POST");
    expect(captured!.url.path, "/v1/notifications/notification-1/respond");
    expect(jsonDecode(captured!.body), {"reaction": "started"});
  });

  test("plan patch includes a selected originPlaceId", () async {
    http.Request? captured;
    final repository = await _repository((request) async {
      captured = request;
      return http.Response("{}", 500);
    });

    await expectLater(
      repository.updatePlan("plan-1", originPlaceId: "place-1"),
      throwsA(anything),
    );

    expect(captured, isNotNull);
    expect(captured!.method, "PATCH");
    expect(captured!.url.path, "/v1/plans/plan-1");
    expect(jsonDecode(captured!.body), {"originPlaceId": "place-1"});
  });

  test("event creation sends timestamps as explicit UTC instants", () async {
    http.Request? captured;
    final repository = await _repository((request) async {
      captured = request;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            "eventId": "event-1",
            "displayName": "회의",
            "startsAt": "2026-08-23T05:00:00Z",
            "endsAt": "2026-08-23T06:00:00Z",
            "locationState": "not_required",
          }),
        ),
        200,
        headers: {"content-type": "application/json; charset=utf-8"},
      );
    });

    await repository.createEvent(
      Event(
        eventId: "",
        displayLabel: "회의",
        displayName: "회의",
        startsAt: DateTime.utc(2026, 8, 23, 5),
        endsAt: DateTime.utc(2026, 8, 23, 6),
        locationState: LocationState.notRequired,
      ),
    );

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body["startsAt"], "2026-08-23T05:00:00.000Z");
    expect(body["endsAt"], "2026-08-23T06:00:00.000Z");
  });
}
