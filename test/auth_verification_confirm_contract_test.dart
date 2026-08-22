import "dart:convert";

import "package:ensom/core/auth_service.dart";
import "package:ensom/core/secure_storage_service.dart";
import "package:ensom/network/api_client.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  test(
    "confirm parses the verificationTicket field returned by the API",
    () async {
      final authService = AuthService(
        apiClient: ApiClient(
          baseUrl: "https://api.ensom.test/v1",
          secureStorage: SecureStorageService(),
          httpClient: MockClient((request) async {
            if (!request.url.path.endsWith(
              "/auth/email/verification/confirm",
            )) {
              return http.Response("{}", 404);
            }

            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body, {"email": "user@example.com", "code": "123456"});
            return http.Response(
              jsonEncode({
                "verificationTicket": "verification-ticket",
                "expiresAt": "2026-08-23T12:34:56Z",
              }),
              200,
            );
          }),
        ),
      );

      final result = await authService.confirmVerificationCode(
        email: "user@example.com",
        code: "123456",
      );

      expect(result.ticket, "verification-ticket");
      expect(result.expiresAt, DateTime.utc(2026, 8, 23, 12, 34, 56));
    },
  );
}
