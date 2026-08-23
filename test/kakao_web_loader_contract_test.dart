import "dart:io";

import "package:flutter_test/flutter_test.dart";

void main() {
  test(
    "web Kakao loader waits for the maps module instead of script onLoad",
    () {
      final source = File(
        "lib/core/kakao_web_loader_web.dart",
      ).readAsStringSync();

      expect(source, contains("&autoload=false"));
      expect(source, contains("_loadKakaoMaps("));
      expect(source, contains("_kakaoMapConstructor != null"));
      expect(source, contains('data-ready'));
    },
  );
}
