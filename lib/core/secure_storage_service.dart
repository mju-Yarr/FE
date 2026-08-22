import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:uuid/uuid.dart";

/// M0 "Secure Storage 세션 관리" 항목.
/// accessToken/refreshToken을 평문 저장하지 않고 Keychain(iOS)/
/// EncryptedSharedPreferences(Android)에 저장한다.
///
/// 가정: pubspec.yaml에 flutter_secure_storage가 없다면 추가 필요.
///   dependencies:
///     flutter_secure_storage: ^9.0.0
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kAccessToken = "access_token";
  static const _kRefreshToken = "refresh_token";
  static const _kUserId = "user_id";
  static const _kInstallationId = "installation_id";
  static const _kOnboardingCompleted = "onboarding_completed";
  static const _kOnboardingStep = "onboarding_step";

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
      _storage.write(key: _kUserId, value: userId),
    ]);
  }

  Future<String?> get accessToken => _storage.read(key: _kAccessToken);
  Future<String?> get refreshToken => _storage.read(key: _kRefreshToken);
  Future<String?> get userId => _storage.read(key: _kUserId);

  Future<bool> get hasSession async => (await accessToken) != null;

  /// 기기별 안정적 식별자. 로그인·가입 요청과 FCM 토큰 등록(POST
  /// /push-devices)이 모두 이 값을 쓴다 — 재설치 전까지 같은 기기는
  /// 항상 같은 값을 반환해야 서버가 push_device 행을 갱신이 아니라
  /// 새로 만드는 일을 막을 수 있다. 최초 조회 시 1회 생성해 저장한다.
  Future<String> get installationId async {
    final existing = await _storage.read(key: _kInstallationId);
    if (existing != null) return existing;
    final generated = const Uuid().v4();
    await _storage.write(key: _kInstallationId, value: generated);
    return generated;
  }

  /// 온보딩 완료 영속. 로그인 응답의 isNew=true 시점에 false로 세팅되며,
  /// S-42에서 완료 후 true로 저장한다. BE에 전용 필드가 없으므로 로컬 기준이다.
  Future<bool> get onboardingCompleted async =>
      (await _storage.read(key: _kOnboardingCompleted)) == "true";

  Future<void> setOnboardingCompleted(bool value) =>
      _storage.write(key: _kOnboardingCompleted, value: value.toString());

  /// 온보딩 진행 단계 저장. 앱 강제 종료 후 복귀 시 마지막 단계로 복원한다.
  Future<String?> get onboardingStep => _storage.read(key: _kOnboardingStep);

  Future<void> setOnboardingStep(String step) =>
      _storage.write(key: _kOnboardingStep, value: step);

  /// 로그아웃 시 전체 소거. TRD §14.3 "로그아웃 시 로컬 민감 데이터 제거"
  /// 원칙에 따라 세션뿐 아니라 이 서비스가 관리하는 모든 키를 지운다.
  /// 준비 항목·장소 캐시 등 다른 민감 캐시(Hive)는 이 서비스 책임이
  /// 아니므로, 로그아웃 흐름에서 별도로 같이 호출해야 한다.
  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kOnboardingCompleted),
      _storage.delete(key: _kOnboardingStep),
    ]);
  }

  /// access token 갱신 시 refresh는 유지하고 access만 교체.
  Future<void> updateAccessToken(String accessToken) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
  }
}
