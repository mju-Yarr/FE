import "dart:io";

import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../core/fcm_service.dart";
import "../core/local_notification_service.dart";
import "../network/api_client.dart";
import "auth_providers.dart";

/// API 명세 §3. 앱 진입 시 1회 호출.
/// 홈 렌더에 필요한 전부를 한 번에 내려받는다.
class BootstrapData {
  const BootstrapData({
    required this.user,
    required this.settings,
    required this.permissions,
    required this.wellnessPrefs,
    required this.places,
    required this.prepRules,
    this.nextEvent,
    this.todayPlan,
    required this.engineConfig,
  });

  final BootstrapUser user;
  final BootstrapSettings settings;
  final List<BootstrapPermission> permissions;
  final List<Map<String, dynamic>> wellnessPrefs;
  final List<Map<String, dynamic>> places;
  final List<Map<String, dynamic>> prepRules;
  final Map<String, dynamic>? nextEvent;
  final Map<String, dynamic>? todayPlan;
  final BootstrapEngineConfig engineConfig;

  factory BootstrapData.fromJson(Map<String, dynamic> json) {
    return BootstrapData(
      user: json["user"] != null
          ? BootstrapUser.fromJson(json["user"] as Map<String, dynamic>)
          : const BootstrapUser(
              userId: "",
              nickname: "",
              timezone: "Asia/Seoul",
              accountStatus: "active",
            ),
      settings: BootstrapSettings.fromJson(
        json["settings"] as Map<String, dynamic>? ?? {},
      ),
      permissions:
          (json["permissions"] as List<dynamic>?)
              ?.map(
                (e) => BootstrapPermission.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      wellnessPrefs:
          (json["wellnessPrefs"] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [],
      places:
          (json["places"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [],
      prepRules:
          (json["prepItems"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [],
      nextEvent: json["nextEvent"] as Map<String, dynamic>?,
      todayPlan: json["todayPlan"] as Map<String, dynamic>?,
      engineConfig: BootstrapEngineConfig.fromJson(
        (json["engineConfig"] as Map<String, dynamic>?) ?? {},
      ),
    );
  }
}

class BootstrapUser {
  const BootstrapUser({
    required this.userId,
    required this.nickname,
    required this.timezone,
    required this.accountStatus,
  });

  final String userId;
  final String nickname;
  final String timezone;
  final String accountStatus;

  factory BootstrapUser.fromJson(Map<String, dynamic> json) {
    return BootstrapUser(
      userId: json["userId"] as String? ?? "",
      nickname: json["nickname"] as String? ?? "",
      timezone: json["timezone"] as String? ?? "Asia/Seoul",
      accountStatus: json["accountStatus"] as String? ?? "active",
    );
  }
}

class BootstrapSettings {
  const BootstrapSettings({
    this.initialPrepMinutes,
    required this.arrivalBufferMinutes,
    required this.notificationSensitivity,
    required this.personalizationEnabled,
    required this.autoManageEnabled,
    required this.wellnessEventEnabled,
    required this.lockscreenHideSensitive,
  });

  final int? initialPrepMinutes;
  final int arrivalBufferMinutes;
  final String notificationSensitivity;
  final bool personalizationEnabled;
  final bool autoManageEnabled;
  final bool wellnessEventEnabled;
  final bool lockscreenHideSensitive;

  factory BootstrapSettings.fromJson(Map<String, dynamic> json) {
    return BootstrapSettings(
      initialPrepMinutes: json["initialPrepMinutes"] as int?,
      arrivalBufferMinutes: json["arrivalBufferMinutes"] as int? ?? 10,
      notificationSensitivity:
          json["notificationSensitivity"] as String? ?? "normal",
      personalizationEnabled: json["personalizationEnabled"] as bool? ?? true,
      autoManageEnabled: json["autoManageEnabled"] as bool? ?? true,
      wellnessEventEnabled: json["wellnessEventEnabled"] as bool? ?? false,
      lockscreenHideSensitive: json["lockscreenHideSensitive"] as bool? ?? true,
    );
  }
}

class BootstrapPermission {
  const BootstrapPermission({
    required this.permissionType,
    required this.status,
  });

  final String
  permissionType; // calendar | location | notification | backgroundLocation
  final String status; // granted | denied | notDetermined

  factory BootstrapPermission.fromJson(Map<String, dynamic> json) {
    return BootstrapPermission(
      permissionType: json["permissionType"] as String? ?? "",
      status: json["status"] as String? ?? "notDetermined",
    );
  }
}

class BootstrapEngineConfig {
  const BootstrapEngineConfig({
    required this.calcVersion,
    required this.weightVersion,
  });

  final String calcVersion;
  final String weightVersion;

  factory BootstrapEngineConfig.fromJson(Map<String, dynamic> json) {
    return BootstrapEngineConfig(
      calcVersion:
          json["engineVer"] as String? ??
          json["calcVersion"] as String? ??
          "3.1.0",
      weightVersion:
          json["wisVer"] as String? ?? json["weightVersion"] as String? ?? "w1",
    );
  }
}

/// GET /me/bootstrap를 호출하고 결과를 캐시한다.
/// authNotifier가 authenticated 상태일 때만 유효하다.
///
/// 403 EMAIL_VERIFICATION_REQUIRED 시 AuthNotifier 상태를 전이시킨다.
/// 네트워크 오류(SocketException) 시 retryable로 마킹해 UI가 재시도를
/// 안내할 수 있게 한다.
final bootstrapProvider = FutureProvider<BootstrapData>((ref) async {
  final authState = ref.watch(authNotifierProvider);
  if (authState.status != AuthStatus.authenticated) {
    throw ApiException(code: "NOT_AUTHENTICATED", message: "로그인이 필요합니다.");
  }

  final apiClient = ref.watch(apiClientProvider);

  try {
    final json = await apiClient.get<Map<String, dynamic>>("/me/bootstrap");
    final data = BootstrapData.fromJson(json);

    // TR-10: 잠금화면 민감 정보 숨김 여부는 bootstrap이 유일한 출처다.
    // 로컬 알림·FCM 둘 다 알림을 직접 표시하므로 각자 반영해야 한다.
    final hideSensitive = data.settings.lockscreenHideSensitive;
    LocalNotificationService.instance.updateSettings(
      lockscreenHideSensitive: hideSensitive,
    );
    if (!kIsWeb) {
      FcmService.instance.updateSettings(
        lockscreenHideSensitive: hideSensitive,
      );
    }

    return data;
  } on ApiException catch (e) {
    if (e.code == "EMAIL_VERIFICATION_REQUIRED") {
      // 이메일 미인증 상태 — AuthNotifier로 상태 전이
      ref.read(authNotifierProvider.notifier).onEmailVerificationNeeded();
    }
    rethrow;
  } on SocketException {
    throw ApiException(
      code: "NETWORK_ERROR",
      message: "네트워크에 연결할 수 없어요.",
      retryable: true,
    );
  }
});
