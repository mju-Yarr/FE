import "../models/onboarding_progress.dart";
import "../network/api_client.dart";

/// `/v1/me/onboarding` 전담. 온보딩 진행 상태는 기기가 아니라 계정에 붙는다.
class OnboardingService {
  OnboardingService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  Future<OnboardingProgress> fetch() async {
    final data = await _client.get<Map<String, dynamic>>("/me/onboarding");
    return OnboardingProgress.fromJson(data);
  }

  /// 단계 진입 시점에 호출한다. 완료된 계정에는 서버가 무시하고 완료 상태를
  /// 그대로 돌려주므로(BE OnboardingService.update) 되돌아가지 않는다.
  Future<OnboardingProgress> updateStep(String step) async {
    final data = await _client.patch<Map<String, dynamic>>(
      "/me/onboarding",
      body: {"currentStep": step},
    );
    return OnboardingProgress.fromJson(data);
  }

  Future<OnboardingProgress> complete() async {
    final data = await _client.post<Map<String, dynamic>>(
      "/me/onboarding/complete",
    );
    return OnboardingProgress.fromJson(data);
  }

  /// §13 코치마크는 최초 1회만. 완료 표시는 서버가 기억한다.
  Future<void> markCoachmarkSeen() async {
    await _client.post<void>("/me/onboarding/coachmark-seen");
  }
}
