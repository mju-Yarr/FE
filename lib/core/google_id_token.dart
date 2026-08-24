import "dart:convert";

/// Google ID token의 서버 전송 전 최소 계약 검증 결과입니다.
///
/// 서명 검증은 반드시 백엔드에서 수행해야 합니다. 여기서는 잘못된 OAuth
/// 클라이언트로 발급됐거나 이미 만료된 토큰을 서버에 보내 401을 만드는 일을
/// 방지하기 위해 공개 payload의 aud/exp만 확인합니다.
enum GoogleIdTokenProblem { malformed, wrongAudience, expired }

GoogleIdTokenProblem? validateGoogleIdToken({
  required String idToken,
  required String expectedAudience,
  DateTime? now,
}) {
  try {
    final parts = idToken.split(".");
    if (parts.length != 3) return GoogleIdTokenProblem.malformed;

    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map<String, dynamic>) {
      return GoogleIdTokenProblem.malformed;
    }

    final audience = payload["aud"];
    final audienceMatches =
        audience == expectedAudience ||
        (audience is List && audience.contains(expectedAudience));
    if (!audienceMatches) return GoogleIdTokenProblem.wrongAudience;

    final expiresAtSeconds = payload["exp"];
    if (expiresAtSeconds is! num) return GoogleIdTokenProblem.malformed;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      expiresAtSeconds.toInt() * 1000,
      isUtc: true,
    );
    if (!expiresAt.isAfter((now ?? DateTime.now()).toUtc())) {
      return GoogleIdTokenProblem.expired;
    }

    return null;
  } on FormatException {
    return GoogleIdTokenProblem.malformed;
  }
}
