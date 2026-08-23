import "dart:convert";

import "package:ensom/core/iso8601_offset.dart";
import "package:ensom/core/secure_storage_service.dart";
import "package:ensom/network/api_client.dart";
import "package:ensom/repository/api_ensom_repository.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

/// updatePlan()이 로컬 DateTime을 넘겨받아도 요청 바디의 prepStartAt이
/// 오프셋/Z 있는 ISO-8601이어야 한다(BE java.time.Instant 파싱, API 명세 §1.5).
/// 로컬 DateTime의 toIso8601String()은 오프셋이 없어 BE가 400을 낸다.
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

void main() {
  test(
    "updatePlan serializes prepStartAt as UTC ISO-8601 with a zone",
    () async {
      Map<String, dynamic>? capturedBody;
      final client = ApiClient(
        baseUrl: "https://api.ensom.test/v1",
        secureStorage: _StubStorage(),
        httpClient: MockClient((request) async {
          if (request.url.path.contains("/plans/")) {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            // 파싱은 이 테스트의 관심사가 아니므로 서버 오류로 중단시킨다.
            return http.Response("{}", 500);
          }
          return http.Response("{}", 200);
        }),
      );
      // 보호 요청 capture를 통과하도록 committed 세션을 만든다.
      final generation = client.beginSessionTransition();
      await client.saveSession(
        expectedGeneration: generation,
        accessToken: "access",
        refreshToken: "refresh",
        userId: "user",
      );

      final repo = ApiEnsomRepository(client);
      // 로컬(오프셋 없는) DateTime — plan_edit_sheet가 만드는 값과 동일한 형태.
      final localPrep = DateTime(2026, 8, 20, 14, 0);

      await expectLater(
        repo.updatePlan("plan-1", prepStartAt: localPrep),
        throwsA(anything),
      );

      expect(capturedBody, isNotNull);
      final prep = capturedBody!["prepStartAt"] as String;
      // 오프셋(Z 또는 +HH:MM)이 반드시 포함돼야 한다.
      expect(
        prep.endsWith("Z") || RegExp(r"[+-]\d{2}:\d{2}$").hasMatch(prep),
        isTrue,
        reason: "prepStartAt must carry a timezone; got '$prep'",
      );
      // iso8601WithOffset() 결과는 "+00:00"로 끝난다.
      expect(prep.endsWith("+00:00"), isTrue);
      // 로컬 14:00(KST 가정)이 UTC로 변환됐는지 값 자체도 확인.
      expect(prep, iso8601WithOffset(DateTime(2026, 8, 20, 14, 0)));
    },
  );
}
