import "dart:async";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:hive_ce_flutter/hive_ce_flutter.dart";
import "package:intl/date_symbol_data_local.dart";
import "package:intl/intl.dart";
import "package:kakao_map_sdk/kakao_map_sdk.dart";
import "core/app_config.dart";
import "core/fcm_service.dart";
import "core/kakao_web_loader.dart";
import "core/local_notification_service.dart";
import "hive_registrar.g.dart";
import "local/offline_queue_entry.dart";
import "local/place_cache_entry.dart";
import "providers/geofence_providers.dart";
import "router/app_router.dart";
import "theme/ensom_colors.dart";
import "theme/ensom_theme.dart";
import "widgets/ensom/ensom_system_gate.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  try {
    await _initializeApp();
    runApp(const ProviderScope(child: EnsomApp()));
  } catch (error, stackTrace) {
    debugPrint("[bootstrap] 앱 초기화 실패: $error\n$stackTrace");
    runApp(const _BootstrapFailureApp());
  }
}

Future<void> _initializeApp() async {
  // 캘린더·홈에서 명시적으로 쓰는 한국어 날짜 데이터를 먼저 준비한다.
  await initializeDateFormatting("ko_KR", null);
  Intl.defaultLocale = "ko_KR";

  // Web 지도는 JavaScript 키로 SDK script를 동적 로드한다. 키가 없거나
  // 도메인 인증/네트워크가 실패해도 앱은 계속 뜨고 지도 영역만 저하된다.
  if (kIsWeb && kKakaoJavaScriptAppKey.isNotEmpty) {
    final mapReady = await ensureKakaoWebSdk(kKakaoJavaScriptAppKey);
    if (!mapReady) {
      debugPrint("[kakao] Web 지도 SDK를 불러오지 못해 지도 없이 계속");
    }
  }

  // 웹 Firebase 설정은 아직 없으므로 네이티브에서만 FCM을 초기화한다.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      unawaited(FcmService.instance.retryPendingTokenCleanup());
    } catch (error) {
      debugPrint("[firebase] 초기화 실패 — FCM 비활성, 로컬 알림 폴백만 동작: $error");
    }
  }

  // 앱의 repository가 이 box들을 즉시 사용하므로 실패를 숨기지 않고 상위의
  // bootstrap 오류 화면으로 전환한다. 자동 삭제는 미전송 행동 유실 위험이 있어 하지 않는다.
  await Hive.initFlutter();
  Hive.registerAdapters();
  await Hive.openBox<OfflineQueueEntry>("offline_queue");
  await Hive.openBox<PlaceCacheEntry>("place_cache");

  // 웹 알림은 Firebase Web 설정이 준비되기 전까지 사용하지 않는다.
  if (!kIsWeb) {
    try {
      await LocalNotificationService.instance.initialize();
    } catch (error) {
      debugPrint("[notification] 로컬 알림 초기화 실패 — 알림 없이 계속: $error");
    }
  }

  // Kakao 네이티브 SDK 실패가 앱 전체 부팅을 막지 않게 지도 기능만 저하시킨다.
  if (!kIsWeb && kKakaoNativeAppKey.isNotEmpty) {
    try {
      await KakaoMapSdk.instance.initialize(kKakaoNativeAppKey);
    } catch (error) {
      debugPrint("[kakao] 지도 SDK 초기화 실패 — 지도 없이 계속: $error");
    }
  }
}

class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: EnsomColors.canvas,
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Ensom",
                    style: TextStyle(
                      color: EnsomColors.ink,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    "앱을 준비하지 못했어요.",
                    style: TextStyle(
                      color: EnsomColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "페이지를 새로고침한 뒤 다시 시도해 주세요.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: EnsomColors.inkMuted, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 앱 루트. go_router를 Riverpod provider로 관리해 AuthState 변화 시
/// 자동 리다이렉트가 동작한다.
class EnsomApp extends ConsumerWidget {
  const EnsomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    if (Firebase.apps.isNotEmpty) {
      FcmService.instance.setNotificationTapHandler((metadata) {
        router.go("/notifications/today");
      });
    }
    return MaterialApp.router(
      title: "Ensom",
      theme: buildEnsomTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // §11 전면 차단 4종은 라우터 바깥에서 앱 전체를 덮는다. 라우트로 만들면
      // 차단 중에도 뒤로가기로 빠져나갈 수 있다.
      builder: (context, child) => EnsomSystemGate(
        child: Stack(children: [?child, if (!kIsWeb) const GeofenceSync()]),
      ),
    );
  }
}
