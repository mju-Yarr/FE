import "package:ensom/core/app_config.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("native Kakao map has a default app key", () {
    expect(kKakaoNativeAppKey, isNotEmpty);
  });
}
