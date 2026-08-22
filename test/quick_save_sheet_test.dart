import "package:ensom/models/calendar_connection.dart";
import "package:ensom/models/event.dart";
import "package:ensom/models/plan.dart";
import "package:ensom/providers/calendar_providers.dart";
import "package:ensom/widgets/ensom/ensom_pill_button.dart";
import "package:ensom/widgets/ensom/ensom_quick_save_sheet.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

/// S-45 — 사용자가 입력하는 것은 일정 이름과 저장할 캘린더뿐이다(§3).
/// 고른 캘린더가 결과에 실려 나가지 않으면 서버는 늘 기본 캘린더에 기록한다.
CalendarConnection _connection(List<CalendarSource> sources) =>
    CalendarConnection(
      calendarConnectionId: "c1",
      provider: "google",
      externalAccountId: "me@example.com",
      connectedAt: DateTime.utc(2026, 8, 20),
      sources: sources,
    );

CalendarSource _source(
  String id,
  String name, {
  bool writable = true,
  bool defaultSource = false,
}) => CalendarSource(
  calendarSourceId: id,
  displayName: name,
  writable: writable,
  defaultSource: defaultSource,
  syncEnabled: true,
);

const _route = RouteOption(
  routeOptionId: "ro1",
  routeRank: 1,
  routeType: RouteType.fastest,
  totalMinutes: 20,
  walkMinutes: 5,
  transferCount: 0,
);

Future<QuickSaveResult?> _open(
  WidgetTester tester,
  List<CalendarConnection> connections,
) async {
  tester.view.physicalSize = const Size(834, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  QuickSaveResult? result;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        calendarConnectionsProvider.overrideWith((ref) async => connections),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await EnsomQuickSaveSheet.show(
                  context,
                  destName: "강남역",
                  anchorMode: EventAnchor.arriveBy,
                  at: DateTime(2026, 8, 21, 14),
                  route: _route,
                );
              },
              child: const Text("열기"),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text("열기"));
  await tester.pumpAndSettle();
  return result;
}

Future<void> _enterName(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextField).first, name);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("쓰기 가능한 캘린더가 하나면 선택지를 보여주지 않는다", (tester) async {
    // 고를 게 없는데 선택지를 보여주면 결정할 일이 있는 것처럼 보인다.
    await _open(tester, [
      _connection([_source("s1", "내 캘린더", defaultSource: true)]),
    ]);

    expect(find.text("저장할 캘린더"), findsNothing);
  });

  testWidgets("읽기 전용 캘린더는 선택지에서 빠진다", (tester) async {
    await _open(tester, [
      _connection([
        _source("s1", "내 캘린더", defaultSource: true),
        _source("holiday", "공휴일", writable: false),
      ]),
    ]);

    // 쓰기 가능한 게 하나뿐이므로 선택지 자체가 없다.
    expect(find.text("저장할 캘린더"), findsNothing);
    expect(find.text("공휴일"), findsNothing);
  });

  testWidgets("둘 이상이면 고를 수 있고 기본 캘린더가 미리 선택된다", (tester) async {
    await _open(tester, [
      _connection([
        _source("s1", "내 캘린더", defaultSource: true),
        _source("s2", "업무"),
      ]),
    ]);

    expect(find.text("저장할 캘린더"), findsOneWidget);
    expect(find.text("내 캘린더"), findsOneWidget);
    expect(find.text("업무"), findsOneWidget);
  });

  testWidgets("이름이 비어 있으면 저장이 비활성이다", (tester) async {
    // §8 S-45 "저장은 일정 이름이 있어야만 활성화된다".
    await _open(tester, [
      _connection([_source("s1", "내 캘린더", defaultSource: true)]),
    ]);

    final button = tester.widget<EnsomPillButton>(
      find.widgetWithText(EnsomPillButton, "저장"),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets("고른 캘린더가 저장 결과에 실린다", (tester) async {
    QuickSaveResult? captured;
    tester.view.physicalSize = const Size(834, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarConnectionsProvider.overrideWith(
            (ref) async => [
              _connection([
                _source("s1", "내 캘린더", defaultSource: true),
                _source("s2", "업무"),
              ]),
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  captured = await EnsomQuickSaveSheet.show(
                    context,
                    destName: "강남역",
                    anchorMode: EventAnchor.arriveBy,
                    at: DateTime(2026, 8, 21, 14),
                    route: _route,
                  );
                },
                child: const Text("열기"),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("열기"));
    await tester.pumpAndSettle();

    await _enterName(tester, "강남역 미팅");
    await tester.tap(find.text("업무"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(EnsomPillButton, "저장"));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.detailedEdit, isFalse);
    expect(captured!.label, "강남역 미팅");
    expect(captured!.calendarSourceId, "s2");
  });

  testWidgets("자세히 편집으로 넘어가도 고른 캘린더를 잃지 않는다", (tester) async {
    // §13 "S-45 프리필 — 다시 입력받지 않는다".
    QuickSaveResult? captured;
    tester.view.physicalSize = const Size(834, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarConnectionsProvider.overrideWith(
            (ref) async => [
              _connection([
                _source("s1", "내 캘린더", defaultSource: true),
                _source("s2", "업무"),
              ]),
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  captured = await EnsomQuickSaveSheet.show(
                    context,
                    destName: "강남역",
                    anchorMode: EventAnchor.arriveBy,
                    at: DateTime(2026, 8, 21, 14),
                    route: _route,
                  );
                },
                child: const Text("열기"),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("열기"));
    await tester.pumpAndSettle();

    await _enterName(tester, "강남역 미팅");
    await tester.tap(find.text("업무"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(EnsomPillButton, "더 고칠 게 있으면 자세히 편집"));
    await tester.pumpAndSettle();

    expect(captured!.detailedEdit, isTrue);
    expect(captured!.calendarSourceId, "s2");
    expect(captured!.label, "강남역 미팅");
  });
}
