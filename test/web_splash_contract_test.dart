import "dart:io";

import "package:flutter_test/flutter_test.dart";

void main() {
  test("웹 초기 스플래시가 priming splash 디자인을 유지한다", () {
    final html = File("web/index.html").readAsStringSync();

    expect(html, contains('class="bootstrap-wordmark"'));
    expect(html, contains('aria-label="ENSOM"'));
    expect(html, contains("늦지 않게, 서두르지 않게."));
    expect(html, isNot(contains("다음 일정까지, 언제부터 준비하면")));
    expect(html, contains("font-size: 22px"));
    expect(html, contains("font-size: 11px"));
    expect(html, contains("width: .72em"));
    expect(html, contains('stroke="#4e6810"'));
    expect(html, contains('stroke="#c6f135"'));
    // Flutter 스플래시(splash_screen.dart)와 동일하게 라임 배경 + 워드마크
    // O 자리 링이 직접 도는 방식이다 — 흰 배경도, 별도 스피너도 없다.
    expect(html, contains("background: #c6f135;"));
    expect(html, contains("bootstrap-ring-arc"));
    expect(html, contains("bootstrap-ring-spin"));
    expect(html, isNot(contains("bootstrap-spinner")));
  });

  test("Flutter 스플래시도 priming splash 수치·배경·회전 링을 사용한다", () {
    final source = File(
      "lib/screens/onboarding/splash_screen.dart",
    ).readAsStringSync();

    expect(source, contains("fontSize: 22"));
    expect(source, contains("fontSize: 11"));
    expect(source, contains("letterSpacing: .2"));
    // priming splash 목업처럼 라임 배경 위에 워드마크의 O 자리 링이 직접
    // 돌아간다 — 별도 스피너를 더 두지 않는다(§1.1 "별도 로딩 인디케이터를
    // 두지 않는다").
    expect(source, contains("backgroundColor: EnsomColors.lime"));
    expect(source, contains("animate: true"));
    expect(source, isNot(contains("다음 일정까지, 언제부터 준비하면")));
  });
}
