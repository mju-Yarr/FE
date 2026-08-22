/// BE `OnboardingProgressResponse` (GET/PATCH `/v1/me/onboarding`).
///
/// 온보딩 진행 단계의 단일 출처를 서버로 옮긴다. 기존에는 SecureStorage에만
/// 있어서 기기를 바꾸거나 앱을 지우면 완료한 온보딩을 다시 하게 됐다.
class OnboardingProgress {
  const OnboardingProgress({
    required this.currentStep,
    required this.completed,
    this.completedAt,
    this.coachmarkSeen = false,
  });

  factory OnboardingProgress.fromJson(Map<String, dynamic> json) {
    return OnboardingProgress(
      currentStep: json["currentStep"] as String? ?? firstStep,
      completed: json["completed"] as bool? ?? false,
      completedAt: json["completedAt"] == null
          ? null
          : DateTime.parse(json["completedAt"] as String),
      coachmarkSeen: json["coachmarkSeen"] as bool? ?? false,
    );
  }

  /// BE `OnboardingService.FIRST_STEP`.
  static const firstStep = "profile";

  final String currentStep;
  final bool completed;
  final DateTime? completedAt;

  /// §13 "코치마크 — 최초 1회만". 완료 여부도 서버가 기억한다.
  final bool coachmarkSeen;

  /// BE STEPS 집합은 명세 §4.1의 가입 플로우 순서를 그대로 따른다.
  ///   S-03 준비시간 → S-04 주요장소 → S-34 캘린더 프라이밍 → 첫 일정
  ///   → S-34 위치 프라이밍 → 첫 계획 생성 → S-34 알림 프라이밍
  ///   → S-05 웰니스 → S-42 완료
  /// 모든 단계를 덮어야 복원 시 빈 곳으로 떨어지지 않는다.
  /// 완료 상태면 null — 호출부가 홈으로 보낸다.
  String? get route {
    if (completed) return null;
    return switch (currentStep) {
      // 가입 직후 초기값. 첫 온보딩 화면은 S-03 준비 시간이다.
      "profile" || "prep" => "/onboarding/prep-time",
      "places" => "/onboarding/places",
      "calendar" => "/onboarding/priming/calendar",
      // §4.1의 "첫 일정" 단계. 아직 온보딩 전용 안내 화면이 없어 일반 일정
      // 생성 폼으로 보낸다.
      "first_event" => "/calendar/new",
      "permissions" => "/onboarding/priming/location",
      "wellness" => "/onboarding/wellness",
      _ => "/onboarding/prep-time",
    };
  }

  OnboardingProgress copyWith({
    String? currentStep,
    bool? completed,
    DateTime? completedAt,
    bool? coachmarkSeen,
  }) => OnboardingProgress(
    currentStep: currentStep ?? this.currentStep,
    completed: completed ?? this.completed,
    completedAt: completedAt ?? this.completedAt,
    coachmarkSeen: coachmarkSeen ?? this.coachmarkSeen,
  );
}
