import "package:ensom/core/app_config.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("native Kakao map has a default app key", () {
    expect(kKakaoNativeAppKey, "51b8598283169d6ec85c8c934783c2da");
  });

  test("web Kakao map has a default JavaScript app key", () {
    expect(kKakaoJavaScriptAppKey, "a18e422a8a32a78ca9753aad386d26d0");
  });

  // 회귀 테스트: OAUTH_GOOGLE_CLIENT_ID dart-define이 빠지거나(혹은 이름이
  // 다른 --dart-define=GOOGLE_SERVER_CLIENT_ID=...처럼 오타나면) 조용히
  // defaultValue(빈 문자열)로 떨어져 구글 로그인/캘린더 연동 버튼이 통째로
  // 숨겨졌었다. 카카오 키처럼 defaultValue 자체에 값을 박아 두면 이 실패
  // 모드가 구조적으로 사라진다 — 이 값이 다시 비워지지 않는지 확인한다.
  test("Google OAuth client ID has a default value", () {
    expect(kGoogleServerClientId, isNotEmpty);
    expect(kGoogleServerClientId, endsWith(".apps.googleusercontent.com"));
  });
}
