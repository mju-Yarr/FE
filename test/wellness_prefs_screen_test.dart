import "package:ensom/models/wellness_pref.dart";
import "package:ensom/repository/ensom_repository.dart";
import "package:ensom/repository/providers.dart";
import "package:ensom/screens/settings/wellness_prefs_screen.dart";
import "package:ensom/widgets/ensom/ensom_toggle.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

/// ensom_profile.html #v-well을 반영한다: 관심 환경 항목/선크림 재도포
/// 리마인드/일정 중 알림 3개 섹션. wellness-prefs·settings 호출만 관측하는
/// 최소 fake — 나머지 추상 메서드는 이 화면이 호출하지 않는다.
class _FakeRepo implements EnsomRepository {
  List<WellnessPref> prefs = const [
    WellnessPref(topic: "uv", isEnabled: true, remindIntervalMinutes: 120),
    WellnessPref(topic: "pm", isEnabled: true),
    WellnessPref(topic: "temp", isEnabled: false),
    WellnessPref(topic: "rain", isEnabled: false),
    WellnessPref(topic: "hydration", isEnabled: false),
  ];
  List<WellnessPref>? lastSaved;

  Map<String, dynamic> settings = {"wellnessEventEnabled": false};
  Map<String, dynamic>? lastSettingsPatch;

  @override
  Future<List<WellnessPref>> fetchWellnessPrefs() async => prefs;

  @override
  Future<void> updateWellnessPrefs(List<WellnessPref> newPrefs) async {
    lastSaved = newPrefs;
    prefs = newPrefs;
  }

  @override
  Future<Map<String, dynamic>> fetchSettings() async => settings;

  @override
  Future<void> updateSettings(Map<String, dynamic> patch) async {
    lastSettingsPatch = patch;
    settings = {...settings, ...patch};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<void> _pumpScreen(WidgetTester tester, _FakeRepo repo) async {
  // 유한 큰 뷰포트로 전체 화면을 스크롤 없이 렌더한다(ListView는 뷰포트
  // 밖의 자식을 Element로 mount하지 않아 find.text가 못 찾는다).
  tester.view.physicalSize = const Size(834, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [ensomRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: WellnessPrefsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("목업 3개 섹션과 항목 라벨을 그대로 보여준다", (tester) async {
    final repo = _FakeRepo();
    await _pumpScreen(tester, repo);

    expect(find.text("관심 환경 항목"), findsOneWidget);
    expect(find.text("선크림 재도포 리마인드"), findsOneWidget);
    expect(find.text("일정 중 알림"), findsOneWidget);

    expect(find.text("자외선"), findsOneWidget);
    expect(find.text("미세먼지"), findsOneWidget);
    expect(find.text("강수"), findsOneWidget);
    expect(find.text("수분"), findsOneWidget);

    expect(find.text("재도포 리마인드"), findsOneWidget);
    expect(find.text("일정 진행 중 이벤트 알림"), findsOneWidget);

    // uv의 remindIntervalMinutes가 120이므로 재도포 주기 카드가 열려 있고
    // "2시간" 칩이 선택돼 있어야 한다.
    expect(find.text("재도포 주기"), findsOneWidget);
    expect(find.text("2시간"), findsOneWidget);
  });

  testWidgets("항목 토글을 누르면 전체 목록이 저장되고 롤백되지 않는다", (tester) async {
    final repo = _FakeRepo();
    await _pumpScreen(tester, repo);

    // 목업처럼 토글 자체에만 탭 핸들러가 있다(행 전체가 아님).
    // 순서: uv(0) pm(1) temp(2) rain(3) hydration(4) → 미세먼지는 index 1.
    await tester.tap(find.byType(EnsomToggle).at(1));
    await tester.pumpAndSettle();

    expect(repo.lastSaved, isNotNull);
    final pm = repo.lastSaved!.firstWhere((p) => p.topic == "pm");
    expect(pm.isEnabled, isFalse);
  });

  testWidgets("일정 중 알림 토글은 wellness-prefs가 아니라 settings로 저장된다", (
    tester,
  ) async {
    final repo = _FakeRepo();
    await _pumpScreen(tester, repo);

    // 순서: uv/pm/temp/rain/hydration(0~4) → 재도포 리마인드(5) → 일정 중 알림(6).
    await tester.tap(find.byType(EnsomToggle).at(6));
    await tester.pumpAndSettle();

    expect(repo.lastSettingsPatch, {"wellnessEventEnabled": true});
    expect(repo.lastSaved, isNull);
  });

  testWidgets("재도포 리마인드를 끄면 remindIntervalMinutes가 null로 저장된다", (
    tester,
  ) async {
    final repo = _FakeRepo();
    await _pumpScreen(tester, repo);

    await tester.tap(find.byType(EnsomToggle).at(5));
    await tester.pumpAndSettle();

    final uv = repo.lastSaved!.firstWhere((p) => p.topic == "uv");
    expect(uv.remindIntervalMinutes, isNull);
    // 꺼졌으니 주기 카드도 사라진다.
    expect(find.text("재도포 주기"), findsNothing);
  });
}
