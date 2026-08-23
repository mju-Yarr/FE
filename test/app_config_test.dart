import "package:ensom/core/app_config.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("native Kakao map has a default app key", () {
    expect(kKakaoNativeAppKey, "51b8598283169d6ec85c8c934783c2da");
  });

  test("web Kakao map has a default JavaScript app key", () {
    expect(kKakaoJavaScriptAppKey, "a18e422a8a32a78ca9753aad386d26d0");
  });
}
