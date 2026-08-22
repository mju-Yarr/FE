import "dart:async";

import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_riverpod/legacy.dart";
import "../core/app_config.dart";
import "../core/auth_service.dart";
import "../core/fcm_service.dart";
import "../core/onboarding_service.dart";
import "../core/secure_storage_service.dart";
import "../models/onboarding_progress.dart";
import "../network/api_client.dart";
import "map_providers.dart";

/// 앱 전역 싱글턴 — 앱 라이프사이클 동안 유지
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return ApiClient(baseUrl: kApiBaseUrl, secureStorage: secureStorage);
});

final authServiceProvider = Provider<AuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthService(apiClient: apiClient);
});

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OnboardingService(apiClient: apiClient);
});

/// 인증 상태 — 앱 전체에서 로그인 여부, 온보딩 완료 여부를 추적한다.
/// 라우터 리다이렉트의 판단 기준.
enum AuthStatus {
  unknown, // 초기 상태 (세션 확인 중)
  sessionCheckFailed, // 기존 세션 검증 중 네트워크 오류
  unauthenticated, // 세션 없음
  emailVerificationRequired, // 로그인됨 but 이메일 미인증
  consentRequired, // 로그인됨 but 약관 미동의
  onboarding, // 신규 사용자 온보딩 진행 중
  authenticated, // 정상 로그인 완료
}

class AuthState {
  const AuthState({
    required this.status,
    this.userId,
    this.email,
    this.consentRequired = const [],
    this.onboarding,
    this.errorMessage,
  });

  final AuthStatus status;
  final String? userId;
  final String? email;
  final List<String> consentRequired;

  /// 서버가 판정한 온보딩 진행 상태(§6.2 가드 3). 라우터가 재개 지점을
  /// 여기서 읽는다.
  final OnboardingProgress? onboarding;

  final String? errorMessage;

  bool get onboardingRequired => onboarding != null && !onboarding!.completed;

  /// 온보딩 재개 경로. 완료됐거나 정보가 없으면 null.
  String? get onboardingRoute => onboarding?.route;

  static const initial = AuthState(status: AuthStatus.unknown);
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required this.authService,
    required this.secureStorage,
    required this.apiClient,
    required this.clearMapDraft,
    this.onboardingService,
    Future<void> Function(ApiClient apiClient, String installationId)?
    initializeFcm,
    Future<void> Function()? disposeFcm,
  }) : _initializeFcm =
           initializeFcm ??
           ((apiClient, installationId) => FcmService.instance.initialize(
             apiClient: apiClient,
             installationId: installationId,
           )),
       // FcmService.instance.dispose처럼 바로 tear-off하면 이 생성자
       // 실행 시점에 FcmService 싱글턴이 즉시 만들어진다 — 필드 초기화자
       // (FirebaseMessaging.instance)가 Firebase 앱 없이 실행돼 웹에서
       // [core/no-app] 예외로 앱 부팅 자체를 막았다. 람다로 감싸 실제
       // 로그아웃 시점까지 접근을 미룬다.
       _disposeFcm = disposeFcm ?? (() => FcmService.instance.dispose()),
       super(AuthState.initial) {
    _sessionCheckCompletion = _checkExistingSession();
  }

  final AuthService authService;
  final SecureStorageService secureStorage;
  final ApiClient apiClient;
  final Future<void> Function() clearMapDraft;

  /// 기존 단위 테스트가 이 notifier를 직접 만들 수 있게 nullable로 둔다.
  final OnboardingService? onboardingService;
  final Future<void> Function(ApiClient apiClient, String installationId)
  _initializeFcm;
  final Future<void> Function() _disposeFcm;
  int? _terminalSourceGeneration;
  Future<void>? _terminalAuthExpiryFuture;
  Future<void> _sessionCheckCompletion = Future<void>.value();

  /// 생성자 또는 retry가 시작한 최신 bootstrap 검사의 실제 완료 Future.
  Future<void> get sessionCheckCompletion => _sessionCheckCompletion;

  /// 앱 시작 시 기존 세션을 서버에서 검증한다.
  Future<void> _checkExistingSession() async {
    final checkGeneration = apiClient.sessionGeneration;
    state = const AuthState(status: AuthStatus.unknown);
    final hasToken = await secureStorage.hasSession;
    if (!apiClient.isCurrentSessionGeneration(checkGeneration)) return;
    if (!hasToken) {
      await clearMapDraft();
      if (apiClient.isCurrentSessionGeneration(checkGeneration)) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
      return;
    }

    final bootstrapGeneration = apiClient.sessionGeneration;
    try {
      // refresh가 필요하면 ApiClient가 처리한다. 세션 검사 네트워크 실패와
      // 인증 실패를 구분하기 위해 실제 인증 필요 API를 호출한다.
      final bootstrap = await apiClient.get<Map<String, dynamic>>(
        "/me/bootstrap",
      );
      if (!apiClient.isCurrentSessionGeneration(bootstrapGeneration)) return;
      // 온보딩 진행 상태의 출처는 서버다. SecureStorage를 보면 기기를 바꾼
      // 사용자가 이미 끝낸 온보딩을 처음부터 다시 하게 된다.
      final onboarding = _readBootstrapOnboarding(bootstrap);
      if (onboarding != null && !onboarding.completed) {
        state = AuthState(
          status: AuthStatus.onboarding,
          onboarding: onboarding,
        );
        _syncFcm();
        return;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        onboarding: onboarding,
      );
      _syncFcm();
    } on ApiException catch (e) {
      if (!apiClient.isCurrentSessionGeneration(bootstrapGeneration) ||
          e.code == "STALE_SESSION") {
        return;
      }
      if (e.isNetworkError || e.retryable) {
        state = const AuthState(
          status: AuthStatus.sessionCheckFailed,
          errorMessage: "네트워크에 연결할 수 없어요. 연결을 확인하고 다시 시도해주세요.",
        );
        return;
      }
      if (e.code == "EMAIL_VERIFICATION_REQUIRED") {
        state = const AuthState(status: AuthStatus.emailVerificationRequired);
        return;
      }
      if (e.isAuthExpired && state.status == AuthStatus.unauthenticated) {
        return;
      }
      await onTerminalAuthExpired(bootstrapGeneration);
    } catch (_) {
      if (!apiClient.isCurrentSessionGeneration(bootstrapGeneration)) return;
      state = const AuthState(
        status: AuthStatus.sessionCheckFailed,
        errorMessage: "세션을 확인하지 못했어요. 잠시 후 다시 시도해주세요.",
      );
    }
  }

  /// BootstrapResponse.gate.onboarding. 구버전 서버가 gate를 안 주면 null을
  /// 돌려주고, 호출부는 온보딩을 강제하지 않는다.
  OnboardingProgress? _readBootstrapOnboarding(Map<String, dynamic> bootstrap) {
    final gate = bootstrap["gate"] as Map<String, dynamic>?;
    final onboarding = gate?["onboarding"] as Map<String, dynamic>?;
    return onboarding == null ? null : OnboardingProgress.fromJson(onboarding);
  }

  Future<void> retrySessionCheck() {
    final completion = _checkExistingSession();
    _sessionCheckCompletion = completion;
    return completion;
  }

  /// 서버 응답을 기다릴 수 없는 손상 세션에서 로컬 인증 정보만 폐기한다.
  /// 서버 logout은 호출하지 않으므로 splash의 복구 버튼이 즉시 동작한다.
  Future<void> discardLocalSession() async {
    final cleanupGeneration = apiClient.beginSessionTransition();
    await Future.wait([
      _bestEffort(
        () => apiClient.clearSession(expectedGeneration: cleanupGeneration),
      ),
      _bestEffort(clearMapDraft),
      _bestEffort(_disposeFcm),
    ]);
    if (apiClient.isCurrentSessionGeneration(cleanupGeneration)) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// main.dart가 Firebase.initializeApp() + 백그라운드 핸들러 등록까지는
  /// 이미 해 뒀다. 로그인 이후 단계(권한 요청, 토큰 획득, POST
  /// /push-devices 등록)는 apiClient가 있어야 하므로 여기서 이어 붙인다.
  void _syncFcm() {
    if (kIsWeb) return; // 웹은 firebase_options.dart가 없어 FCM 자체를 안 쓴다.
    final generation = apiClient.sessionGeneration;
    unawaited(() async {
      final installationId = await secureStorage.installationId;
      if (!apiClient.isCurrentSessionGeneration(generation)) return;
      await _initializeFcm(apiClient, installationId);
    }());
  }

  int _beginLoginTransition() {
    final generation = apiClient.beginSessionTransition();
    _terminalSourceGeneration = null;
    _terminalAuthExpiryFuture = null;
    return generation;
  }

  /// S-16 atomic 가입. 화면 안에서 이메일 인증을 이미 끝냈으므로 티켓과 약관을
  /// 함께 보낸다. 가입 응답에는 토큰이 없고(BE SignupResponse), 이어서 S-18에서
  /// 로그인해 세션을 만든다.
  Future<SignupResult> signupWithEmail({
    required String email,
    required String password,
    required String verificationTicket,
    required Map<String, bool> consents,
    String? name,
    String? nickname,
    String? timezone,
  }) async {
    final installationId = await secureStorage.installationId;
    return authService.signupWithEmail(
      email: email,
      password: password,
      verificationTicket: verificationTicket,
      consents: consents,
      name: name,
      nickname: nickname,
      timezone: timezone,
      installationId: installationId,
    );
  }

  /// 이메일 로그인 성공
  Future<void> loginWithEmail({
    required String email,
    required String password,
    String? installationId,
  }) async {
    final loginGeneration = _beginLoginTransition();
    try {
      final result = await authService.loginWithEmail(
        email: email,
        password: password,
        expectedGeneration: loginGeneration,
        installationId: installationId,
      );
      _handleLoginResult(
        result,
        expectedGeneration: loginGeneration,
        email: email,
      );
    } catch (_) {
      await _bestEffort(
        () => apiClient.clearSession(expectedGeneration: loginGeneration),
      );
      rethrow;
    }
  }

  /// Google 로그인 성공
  Future<void> loginWithGoogle({
    required String idToken,
    required String installationId,
  }) async {
    final loginGeneration = _beginLoginTransition();
    try {
      final result = await authService.loginWithGoogle(
        idToken: idToken,
        installationId: installationId,
        expectedGeneration: loginGeneration,
      );
      _handleLoginResult(result, expectedGeneration: loginGeneration);
    } catch (_) {
      await _bestEffort(
        () => apiClient.clearSession(expectedGeneration: loginGeneration),
      );
      rethrow;
    }
  }

  /// 약관 동의 완료 후 신규 사용자는 온보딩을 이어가고, 약관 개정에
  /// 동의한 기존 사용자는 정상 로그인 상태로 돌아간다.
  void onConsentCompleted() {
    state = AuthState(
      status: state.onboardingRequired
          ? AuthStatus.onboarding
          : AuthStatus.authenticated,
      userId: state.userId,
      onboarding: state.onboarding,
    );
    _syncFcm();
  }

  /// 온보딩 단계를 서버에 기록하고 상태에 반영한다. 단계 이동은 화면 전환의
  /// 부수 효과이지 관문이 아니므로, 기록에 실패해도 흐름을 막지 않고 로컬에만
  /// 남긴다 — 여기서 사용자를 세우면 온보딩 중간에 갇힌다.
  Future<void> advanceOnboarding(String step) async {
    await _bestEffort(() => secureStorage.setOnboardingStep(step));
    final service = onboardingService;
    if (service == null) return;
    try {
      onOnboardingProgressed(await service.updateStep(step));
    } catch (_) {
      // 다음 진입 때 bootstrap이 서버 상태를 다시 읽어 정렬한다.
    }
  }

  /// 온보딩 단계 진행. 서버가 돌려준 진행 상태를 그대로 반영해서
  /// 앱을 껐다 켜도 같은 자리에서 이어진다.
  void onOnboardingProgressed(OnboardingProgress progress) {
    state = AuthState(
      status: progress.completed
          ? AuthStatus.authenticated
          : AuthStatus.onboarding,
      userId: state.userId,
      onboarding: progress,
    );
    if (progress.completed) _syncFcm();
  }

  Future<void> onOnboardingCompleted() async {
    // 로컬 플래그는 구버전 서버 호환용으로만 남긴다. 판정 기준은 서버다.
    await secureStorage.setOnboardingCompleted(true);
    await _bestEffort(() async {
      final progress = await onboardingService?.complete();
      if (progress != null) onOnboardingProgressed(progress);
    });
    if (state.status == AuthStatus.authenticated) return;
    state = AuthState(
      status: AuthStatus.authenticated,
      userId: state.userId,
      onboarding:
          (state.onboarding ??
                  const OnboardingProgress(
                    currentStep: "completed",
                    completed: true,
                  ))
              .copyWith(currentStep: "completed", completed: true),
    );
  }

  /// 이메일 인증 확인 완료 후 상태 전이
  void onEmailVerified() {
    state = AuthState(status: AuthStatus.authenticated, userId: state.userId);
    _syncFcm();
  }

  /// bootstrap이 403 EMAIL_VERIFICATION_REQUIRED를 받았을 때
  void onEmailVerificationNeeded() {
    state = AuthState(
      status: AuthStatus.emailVerificationRequired,
      userId: state.userId,
      email: state.email,
    );
  }

  /// 실행 중 401 후 refresh token이 거부된 terminal 만료 처리.
  /// 요청 시작 generation이 현재와 일치할 때만 세션을 무효화한다.
  Future<void> onTerminalAuthExpired(int sourceGeneration) {
    if (_terminalSourceGeneration == sourceGeneration &&
        _terminalAuthExpiryFuture != null) {
      return _terminalAuthExpiryFuture!;
    }

    final cleanupGeneration = apiClient.invalidateSessionGeneration(
      sourceGeneration,
    );
    if (cleanupGeneration == null) return Future<void>.value();

    _terminalSourceGeneration = sourceGeneration;
    final future = _expireTerminalSession(cleanupGeneration);
    _terminalAuthExpiryFuture = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_terminalAuthExpiryFuture, future)) {
          _terminalSourceGeneration = null;
          _terminalAuthExpiryFuture = null;
        }
      }),
    );
    return future;
  }

  Future<void> _expireTerminalSession(int cleanupGeneration) async {
    await Future.wait([
      _bestEffort(
        () => apiClient.clearSession(expectedGeneration: cleanupGeneration),
      ),
      _bestEffort(clearMapDraft),
      _bestEffort(_disposeFcm),
    ]);
    if (apiClient.isCurrentSessionGeneration(cleanupGeneration)) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _bestEffort(Future<void> Function() cleanup) async {
    try {
      await cleanup();
    } catch (_) {
      // 로컬 cleanup 일부 실패가 terminal 상태 전이를 막지 않는다.
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    final logoutGeneration = apiClient.beginSessionTransition();
    await Future.wait([
      _bestEffort(
        () => authService.logout(expectedGeneration: logoutGeneration),
      ),
      _bestEffort(clearMapDraft),
      _bestEffort(_disposeFcm),
    ]);
    if (apiClient.isCurrentSessionGeneration(logoutGeneration)) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  void _handleLoginResult(
    LoginResult result, {
    required int expectedGeneration,
    String? email,
  }) {
    if (!apiClient.isCurrentSessionGeneration(expectedGeneration)) return;
    _terminalAuthExpiryFuture = null;
    // §6.2 가드는 순서대로 평가한다 — 약관을 통과해야 온보딩을 검사한다.
    // 미인증 이메일은 BE가 로그인 자체를 403 EMAIL_VERIFICATION_REQUIRED로
    // 막으므로 여기까지 오지 않는다.
    if (result.consentRequired.isNotEmpty) {
      state = AuthState(
        status: AuthStatus.consentRequired,
        userId: result.userId,
        email: email,
        consentRequired: result.consentRequired,
        onboarding: result.onboarding,
      );
      return;
    }
    final onboarding = result.onboarding;
    if (onboarding != null && !onboarding.completed) {
      state = AuthState(
        status: AuthStatus.onboarding,
        userId: result.userId,
        email: email,
        onboarding: onboarding,
      );
      _syncFcm();
      return;
    }
    state = AuthState(
      status: AuthStatus.authenticated,
      userId: result.userId,
      email: email,
      onboarding: onboarding,
    );
    _syncFcm();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  final authService = ref.watch(authServiceProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final apiClient = ref.watch(apiClientProvider);
  final notifier = AuthNotifier(
    authService: authService,
    secureStorage: secureStorage,
    apiClient: apiClient,
    clearMapDraft: () => ref.read(mapDraftEventProvider.notifier).clear(),
    onboardingService: ref.watch(onboardingServiceProvider),
  );
  apiClient.setAuthExpiredHandler(notifier.onTerminalAuthExpired);
  ref.onDispose(() => apiClient.setAuthExpiredHandler(null));
  return notifier;
});
