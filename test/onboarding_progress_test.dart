import "package:ensom/models/onboarding_progress.dart";
import "package:flutter_test/flutter_test.dart";

/// 온보딩 재개 지점은 라우터 가드가 그대로 따르는 값이라, BE STEPS 집합을
/// 하나라도 못 덮으면 사용자가 엉뚱한 화면에 떨어진다.
void main() {
  test("BE의 모든 단계가 화면 경로로 매핑된다", () {
    // BE OnboardingService.STEPS — completed는 route가 null이라 따로 본다.
    const steps = [
      "profile",
      "prep",
      "places",
      "calendar",
      "first_event",
      "permissions",
      "wellness",
    ];
    for (final step in steps) {
      final progress = OnboardingProgress(currentStep: step, completed: false);
      expect(progress.route, isNotNull, reason: "$step 단계에 대응하는 경로가 없다");
      expect(progress.route, startsWith("/"));
    }
  });

  test("명세 §4.1 순서대로 경로가 이어진다", () {
    String routeOf(String step) =>
        OnboardingProgress(currentStep: step, completed: false).route!;

    expect(routeOf("profile"), "/onboarding/prep-time");
    expect(routeOf("prep"), "/onboarding/prep-time");
    expect(routeOf("places"), "/onboarding/places");
    expect(routeOf("calendar"), "/onboarding/priming/calendar");
    expect(routeOf("permissions"), "/onboarding/priming/location");
    expect(routeOf("wellness"), "/onboarding/wellness");
  });

  test("완료 상태는 재개 경로를 주지 않는다", () {
    const done = OnboardingProgress(currentStep: "completed", completed: true);
    expect(done.route, isNull);

    // completed 플래그가 우선이다 — currentStep이 남아 있어도 되돌리지 않는다.
    const staleStep = OnboardingProgress(
      currentStep: "places",
      completed: true,
    );
    expect(staleStep.route, isNull);
  });

  test("모르는 단계는 온보딩 첫 화면으로 보낸다", () {
    const unknown = OnboardingProgress(
      currentStep: "something_new",
      completed: false,
    );
    expect(unknown.route, "/onboarding/prep-time");
  });

  test("fromJson은 서버 응답을 그대로 읽는다", () {
    final progress = OnboardingProgress.fromJson({
      "currentStep": "places",
      "completed": false,
      "completedAt": null,
      "coachmarkSeen": true,
    });
    expect(progress.currentStep, "places");
    expect(progress.completed, isFalse);
    expect(progress.coachmarkSeen, isTrue);
    expect(progress.completedAt, isNull);
  });

  test("필드가 빠진 응답은 첫 단계·미완료로 읽는다", () {
    final progress = OnboardingProgress.fromJson(const {});
    expect(progress.currentStep, OnboardingProgress.firstStep);
    expect(progress.completed, isFalse);
    expect(progress.coachmarkSeen, isFalse);
    expect(progress.route, "/onboarding/prep-time");
  });
}
