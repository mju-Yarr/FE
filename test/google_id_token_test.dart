import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:ensom/core/google_id_token.dart";

String _token(Map<String, Object> payload) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll("=", "");
  return "${encode({"alg": "none"})}.${encode(payload)}.signature";
}

void main() {
  const clientId = "new-client.apps.googleusercontent.com";
  final now = DateTime.utc(2026, 8, 25);

  test("accepts a current token issued for the configured client", () {
    final result = validateGoogleIdToken(
      idToken: _token({
        "aud": clientId,
        "exp":
            now.add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000,
      }),
      expectedAudience: clientId,
      now: now,
    );

    expect(result, isNull);
  });

  test("rejects a token issued for the previous client", () {
    final result = validateGoogleIdToken(
      idToken: _token({
        "aud": "old-client.apps.googleusercontent.com",
        "exp":
            now.add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000,
      }),
      expectedAudience: clientId,
      now: now,
    );

    expect(result, GoogleIdTokenProblem.wrongAudience);
  });

  test("rejects an expired cached token", () {
    final result = validateGoogleIdToken(
      idToken: _token({
        "aud": clientId,
        "exp":
            now.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch ~/
            1000,
      }),
      expectedAudience: clientId,
      now: now,
    );

    expect(result, GoogleIdTokenProblem.expired);
  });
}
