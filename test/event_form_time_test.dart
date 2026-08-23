import "package:flutter_test/flutter_test.dart";
import "package:ensom/screens/calendar/event_form_screen.dart";

void main() {
  group("일정 생성 초기 시각", () {
    test("현재 시각 한 시간 뒤를 다음 30분 단위로 올림한다", () {
      expect(
        nextEventStartTime(DateTime(2026, 8, 23, 10, 5)),
        DateTime(2026, 8, 23, 11, 30),
      );
      expect(
        nextEventStartTime(DateTime(2026, 8, 23, 10, 35)),
        DateTime(2026, 8, 23, 12),
      );
    });

    test("올림 결과가 자정을 넘으면 다음 날짜로 이동한다", () {
      expect(
        nextEventStartTime(DateTime(2026, 8, 23, 22, 45)),
        DateTime(2026, 8, 24),
      );
    });
  });
}
