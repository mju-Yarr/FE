import "dart:convert";

import "package:ensom/core/secure_storage_service.dart";
import "package:ensom/core/auth_service.dart";
import "package:ensom/models/notification.dart";
import "package:ensom/models/event.dart";
import "package:ensom/models/daily_wellness_summary.dart";
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
  test("daily summary accepts the backend unknown band", () {
    final summary = DailyWellnessSummary.fromJson({
      "summaryId": "summary-1",
      "summaryDate": "2026-08-24",
      "eventCount": 0,
      "totalOutdoorMinutes": 0,
      "outdoorSource": "none",
      "onTimeCount": 0,
      "arrivalSampleCount": 0,
      "dwlBand": "unknown",
      "dwlScore": null,
      "cardScenario": "default",
      "message": "",
      "isViewed": false,
    });

    expect(summary.dwlBand, DwlBand.unknown);
    expect(summary.outdoorSource, "none");
  });

  test("session requests send the refresh token identity header", () async {
    http.Request? captured;
    final client = ApiClient(
      baseUrl: "https://api.ensom.test/v1",
      secureStorage: _StubStorage(),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response("[]", 200);
      }),
    );
    final generation = client.beginSessionTransition();
    await client.saveSession(
      expectedGeneration: generation,
      accessToken: "access",
      refreshToken: "refresh",
      userId: "user",
    );

    await client.get<List<dynamic>>("/me/sessions", includeRefreshToken: true);

    expect(captured!.headers["x-refresh-token"], "refresh");
  });

  test("email login sends only fields declared by LoginRequest", () async {
    http.Request? captured;
    final client = ApiClient(
      baseUrl: "https://api.ensom.test/v1",
      secureStorage: _StubStorage(),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            "accessToken": "access",
            "refreshToken": "refresh",
            "user": {
              "userId": "user",
              "nickname": "tester",
              "timezone": "Asia/Seoul",
              "isNew": false,
            },
            "consentRequired": <String>[],
          }),
          200,
        );
      }),
    );
    final generation = client.beginSessionTransition();

    await AuthService(apiClient: client).loginWithEmail(
      email: "test@example.com",
      password: "password123",
      installationId: "local-installation",
      expectedGeneration: generation,
    );

    expect(jsonDecode(captured!.body), {
      "email": "test@example.com",
      "password": "password123",
    });
  });

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
