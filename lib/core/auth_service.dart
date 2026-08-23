import "dart:io";

import "../models/onboarding_progress.dart";
import "../network/api_client.dart";

/// API 명세 §2 인증 엔드포인트 전담 서비스.
/// EnsomRepository와 별도로 존재한다 — 인증은 도메인 리소스가 아니라
/// 세션 수립 경로이며, Bearer 토큰 없이 호출되는 유일한 그룹이기 때문이다.
class AuthService {
  AuthService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  // ─── 이메일 인증 코드 (S-16 인라인) ─────────────────────────────
  /// 가입 화면 안에서 6자리 코드를 받는다. 별도 인증 화면(구 S-17)은
  /// 없어졌다(명세 §14).
  Future<VerificationChallenge> sendVerificationCode(String email) async {
    return _guardNetwork(() async {
      final data = await _client.postPublic<Map<String, dynamic>>(
        "/auth/email/verification/send",
        body: {"email": email},
      );
      return VerificationChallenge(
        challengeId: data["challengeId"] as String,
        expiresAt: DateTime.parse(data["expiresAt"] as String),
      );
    });
  }

  /// 코드가 맞으면 가입에 쓸 티켓을 돌려준다. 티켓 없이는 atomic signup이
  /// 거절된다(BE `VERIFICATION_TICKET_REQUIRED`).
  Future<VerificationTicket> confirmVerificationCode({
    required String email,
    required String code,
  }) async {
    return _guardNetwork(() async {
      final data = await _client.postPublic<Map<String, dynamic>>(
        "/auth/email/verification/confirm",
        body: {"email": email, "code": code},
      );
      return VerificationTicket(
        ticket: data["verificationTicket"] as String,
        expiresAt: DateTime.parse(data["expiresAt"] as String),
      );
    });
  }

  /// S-16 닉네임 중복 확인. 서버가 유니크 인덱스로 최종 판정하므로 이 결과는
  /// 입력 중 힌트일 뿐이고, 가입 시 `NICKNAME_EXISTS`가 다시 날 수 있다.
  Future<bool> isNicknameAvailable(String nickname) async {
    return _guardNetwork(() async {
      final data = await _client.getPublic<Map<String, dynamic>>(
        "/auth/check-nickname",
        query: {"value": nickname},
      );
      return data["available"] as bool? ?? false;
    });
  }

  // ─── 이메일 회원가입 (S-16 atomic) ──────────────────────────────
  /// 이름·닉네임·약관·이메일 인증 티켓을 한 번에 보낸다. 티켓 흐름에서는
  /// BE가 emailVerifiedAt까지 채우므로 가입 직후 바로 로그인할 수 있다.
  /// 토큰은 여전히 발급하지 않는다.
  Future<SignupResult> signupWithEmail({
    required String email,
    required String password,
    required String verificationTicket,
    required Map<String, bool> consents,
    String? name,
    String? nickname,
    String? timezone,
    String? installationId,
  }) async {
    return _guardNetwork(() async {
      final data = await _client.postPublic<Map<String, dynamic>>(
        "/auth/email/signup",
        body: {
          "email": email,
          "password": password,
          "verificationTicket": verificationTicket,
          "consents": consents,
          if (name != null) "name": name,
          if (nickname != null) "nickname": nickname,
          if (timezone != null) "timezone": timezone,
          if (installationId != null) "installationId": installationId,
        },
      );
      return SignupResult(
        userId: (data["id"] ?? "") as String,
        email: (data["email"] ?? email) as String,
        emailVerified: data["emailVerified"] as bool? ?? false,
        verificationSent: data["verificationSent"] as bool? ?? false,
      );
    });
  }

  // ─── 이메일 로그인 (§2.2) ──────────────────────────────────────
  Future<LoginResult> loginWithEmail({
    required String email,
    required String password,
    required int expectedGeneration,
    String? installationId,
  }) async {
    try {
      final data = await _client.postPublic<Map<String, dynamic>>(
        "/auth/email/login",
        body: {"email": email, "password": password},
      );
      return _handleLoginResponse(data, expectedGeneration);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException(
        code: "NETWORK_ERROR",
        message: "네트워크에 연결할 수 없어요.",
        retryable: true,
      );
    }
  }

  // ─── Google 로그인 (§2.5) ──────────────────────────────────────
  /// 현재 BE 매핑: POST /auth/google (dev BE 기준)
  /// API 명세는 POST /auth/login { provider: "google" } 이지만,
  /// BE와 합의해 /auth/google 단일 경로로 확정.
  Future<LoginResult> loginWithGoogle({
    required String idToken,
    required String installationId,
    required int expectedGeneration,
  }) async {
    try {
      final data = await _client.postPublic<Map<String, dynamic>>(
        "/auth/google",
        body: {"idToken": idToken},
      );
      return _handleLoginResponse(data, expectedGeneration);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException(
        code: "NETWORK_ERROR",
        message: "네트워크에 연결할 수 없어요.",
        retryable: true,
      );
    }
  }

  // ─── 이메일 인증 (§2.3) ────────────────────────────────────────
  Future<void> verifyEmail(String token) async {
    await _client.postPublic<Map<String, dynamic>>(
      "/auth/email/verify",
      body: {"token": token},
    );
  }

  Future<void> resendVerification(String email) async {
    await _client.postPublic<Map<String, dynamic>>(
      "/auth/email/verify/resend",
      body: {"email": email},
    );
  }

  // ─── 약관 동의 (§2.8) ─────────────────────────────────────────
  /// 현재 BE 계약: 단건 ConsentRequest + Idempotency-Key 헤더.
  /// ApiClient.post()가 Idempotency-Key를 자동 부여하므로 body에는
  /// 동의 내용만 담는다. 복수 항목은 순차 호출한다.
  Future<void> submitConsents(List<ConsentEntry> consents) async {
    for (final consent in consents) {
      await _client.post<Map<String, dynamic>>(
        "/consents",
        body: consent.toJson(),
      );
    }
  }

  // ─── 로그아웃 (§2.6) ──────────────────────────────────────────
  Future<void> logout({required int expectedGeneration}) async {
    try {
      await _client.post<Map<String, dynamic>>(
        "/auth/logout",
        expectedGeneration: expectedGeneration,
        allowUncommittedSession: true,
      );
    } catch (_) {
      // 로그아웃 서버 호출 실패해도 현재 로그아웃 세대의 로컬 세션은 소거한다.
    } finally {
      await _client.clearSession(expectedGeneration: expectedGeneration);
    }
  }

  // ─── 내부 ─────────────────────────────────────────────────────
  Future<LoginResult> _handleLoginResponse(
    Map<String, dynamic> data,
    int expectedGeneration,
  ) async {
    final accessToken = data["accessToken"] as String;
    final refreshToken = data["refreshToken"] as String;
    final user = data["user"] as Map<String, dynamic>;
    final userId = user["userId"] as String;

    await _client.saveSession(
      expectedGeneration: expectedGeneration,
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
    );

    return LoginResult(
      userId: userId,
      nickname: user["nickname"] as String? ?? "",
      timezone: user["timezone"] as String? ?? "Asia/Seoul",
      isNew: user["isNew"] as bool? ?? false,
      consentRequired:
          (data["consentRequired"] as List<dynamic>?)?.cast<String>() ?? [],
      // §6.2 가드 3 — 온보딩 재개 지점은 서버가 판정한다. isNew는 이메일
      // 로그인에서 항상 false라 온보딩 분기 근거로 쓸 수 없다.
      onboarding: data["onboarding"] == null
          ? null
          : OnboardingProgress.fromJson(
              data["onboarding"] as Map<String, dynamic>,
            ),
    );
  }

  /// SocketException을 API 계약의 NETWORK_ERROR로 바꾼다. 인증 실패와
  /// 네트워크 실패를 UI가 구분해야 하기 때문이다(§13, TRD §2.6).
  Future<T> _guardNetwork<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException(
        code: "NETWORK_ERROR",
        message: "네트워크에 연결할 수 없어요.",
        retryable: true,
      );
    }
  }
}

class VerificationChallenge {
  const VerificationChallenge({
    required this.challengeId,
    required this.expiresAt,
  });

  final String challengeId;
  final DateTime expiresAt;
}

class VerificationTicket {
  const VerificationTicket({required this.ticket, required this.expiresAt});

  final String ticket;
  final DateTime expiresAt;
}

// ─── Result DTOs ──────────────────────────────────────────────────

class SignupResult {
  const SignupResult({
    required this.userId,
    required this.email,
    required this.emailVerified,
    required this.verificationSent,
  });

  final String userId;
  final String email;
  final bool emailVerified;
  final bool verificationSent;
}

class LoginResult {
  const LoginResult({
    required this.userId,
    required this.nickname,
    required this.timezone,
    required this.isNew,
    required this.consentRequired,
    this.onboarding,
  });

  final String userId;
  final String nickname;
  final String timezone;
  final bool isNew;
  final List<String> consentRequired;

  /// BE TokenResponse.onboarding. 구버전 서버는 안 줄 수 있어 nullable이다.
  final OnboardingProgress? onboarding;
}

class ConsentEntry {
  const ConsentEntry({
    required this.consentType,
    required this.policyVersion,
    required this.agreed,
  });

  final String consentType;
  final String policyVersion;
  final bool agreed;

  /// BE 현재 계약: consentType + policyVersion + agreed (boolean).
  /// action/isRequired는 FE 전용 개념이므로 서버에 보내지 않는다.
  Map<String, dynamic> toJson() => {
    "consentType": consentType,
    "policyVersion": policyVersion,
    "agreed": agreed,
  };
}
