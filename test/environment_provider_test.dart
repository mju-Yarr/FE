import "dart:convert";

import "package:ensom/core/secure_storage_service.dart";
import "package:ensom/network/api_client.dart";
import "package:ensom/providers/environment_provider.dart";
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

ApiClient _clientReturning(http.Response response) => ApiClient(
  baseUrl: "https://api.ensom.test/v1",
  secureStorage: _StubStorage(),
  httpClient: MockClient((request) async => response),
);

http.Response _errorResponse(int status, String code) => http.Response(
  jsonEncode({
    "error": {"code": code, "message": "test", "retryable": false},
  }),
  status,
);

void main() {
  // EnvironmentController는 대표 장소 미등록(PRIMARY_PLACE_NOT_FOUND)과
  // 환경 조회 실패(ENVIRONMENT_UNAVAILABLE)를 똑같이 404로 응답한다 — 상태
  // 코드만으로는 구분할 수 없고 반드시 error.code로 분기해야 한다.
  test("대표 장소 미등록(PRIMARY_PLACE_NOT_FOUND)은 null로 처리된다", () async {
    final client = _clientReturning(
      _errorResponse(404, "PRIMARY_PLACE_NOT_FOUND"),
    );

    expect(await fetchEnvironment(client), isNull);
  });

  test("같은 404라도 ENVIRONMENT_UNAVAILABLE은 오류로 던져진다", () async {
    final client = _clientReturning(
      _errorResponse(404, "ENVIRONMENT_UNAVAILABLE"),
    );

    await expectLater(
      fetchEnvironment(client),
      throwsA(isA<ApiException>()),
    );
  });

  test("5xx 등 다른 오류도 null로 숨기지 않고 던져진다", () async {
    final client = _clientReturning(http.Response("", 500));

    await expectLater(fetchEnvironment(client), throwsA(isA<ApiException>()));
  });
}
