import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:ensom/screens/calendar/event_form_screen.dart";
import "package:ensom/widgets/ensom/ensom_date_picker_sheet.dart";

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

  group("날짜 직접 선택 달력", () {
    test("6주 달력과 5주 달력의 셀 수를 올바르게 계산한다", () {
      expect(calendarGridCellCount(DateTime(2026, 8)), 42);
      expect(calendarGridCellCount(DateTime(2026, 9)), 35);
    });

    testWidgets("작은 화면의 6주 달력에서도 확인 버튼을 눌러 선택한다", (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 560));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      DateTime? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selected = await EnsomDatePickerSheet.show(
                  context,
                  initial: DateTime(2026, 8, 23),
                );
              },
              child: const Text("날짜 열기"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("날짜 열기"));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text("확인"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("확인"));
      await tester.pumpAndSettle();

      expect(selected, DateTime(2026, 8, 23));
    });
  });
}
