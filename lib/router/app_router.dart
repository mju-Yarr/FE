import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:permission_handler/permission_handler.dart";
import "../core/permission_service.dart";
import "../theme/ensom_colors.dart";
import "../providers/auth_providers.dart";
import "../providers/map_providers.dart";
import "../screens/onboarding/auth_screen.dart";
import "../screens/onboarding/splash_screen.dart";
import "../screens/onboarding/consent_screen.dart";
import "../screens/onboarding/consent_detail_screen.dart";
import "../screens/onboarding/email_verification_screen.dart";
import "../screens/onboarding/prep_time_entry_screen.dart";
import "../screens/onboarding/wellness_onboarding_screen.dart";
import "../screens/onboarding/onboarding_complete_screen.dart";
import "../screens/onboarding/permission_priming_screen.dart";
import "../screens/onboarding/signup_complete_screen.dart";
import "../screens/home/home_screen.dart";
import "../screens/home/weather_detail_screen.dart";
import "../screens/notifications/notification_log_screen.dart";
import "../screens/places/place_registration_screen.dart";
import "../screens/route/route_selection_screen.dart";
import "../screens/settings/wellness_prefs_screen.dart";
import "../screens/summary/daily_summary_screen.dart";
import "../screens/map/map_screen.dart";
import "../screens/calendar/calendar_screen.dart";
import "../screens/calendar/event_form_screen.dart";
import "../screens/calendar/calendar_sync_screen.dart";
import "../screens/calendar/weekly_report_screen.dart";
import "../screens/detail/event_detail_screen.dart";
import "../screens/search/place_search_screen.dart";
import "../screens/profile/profile_screen.dart";
import "../screens/profile/account_screen.dart";
import "../screens/profile/withdraw_screen.dart";
import "../screens/profile/notification_settings_screen.dart";
import "../screens/profile/personalization_screen.dart";
import "../screens/profile/permissions_screen.dart";
import "../screens/profile/data_management_screen.dart";
import "../screens/profile/change_password_screen.dart";
import "../screens/profile/change_email_screen.dart";
import "../screens/profile/providers_screen.dart";
import "../screens/profile/sessions_screen.dart";
import "../screens/onboarding/password_reset_screen.dart";
import "../screens/map/bookmarks_screen.dart";

const _consentTitles = {
  "terms": "이용약관",
  "privacy": "개인정보 처리방침",
  "location": "위치기반 서비스 이용약관",
  "marketing": "마케팅 정보 수신 동의",
};

/// GoRouter + Riverpod 연동.
/// AuthState를 구독해서 인증 상태 변화 시 자동 리다이렉트.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier(0);
  ref.listen<AuthState>(authNotifierProvider, (_, _) {
    refreshNotifier.value++;
  });
  ref.listen<AsyncValue<MapDraftEvent?>>(mapDraftEventProvider, (_, _) {
    refreshNotifier.value++;
  });
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    refreshListenable: refreshNotifier,
    initialLocation: "/splash",
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final path = state.uri.path;
      // §6.1 "인증 필요 = 아니오" 화면들. 약관 본문은 가입 폼에서 열기 때문에
      // 로그인 전에도 볼 수 있어야 한다.
      final isAuthPage =
          path.startsWith("/onboarding/auth") ||
          path.startsWith("/onboarding/email") ||
          path.startsWith("/onboarding/password-reset") ||
          path.startsWith("/terms/");
      final isConsentPage = path == "/onboarding/consent";

      switch (authState.status) {
        case AuthStatus.unknown:
          // 세션 확인 중 — 스플래시에 머문다
          if (path != "/splash") return "/splash";
          return null;

        case AuthStatus.sessionCheckFailed:
          // 네트워크 오류는 로그아웃으로 간주하지 않고 재시도 가능한
          // 스플래시에 머문다.
          if (path != "/splash") return "/splash";
          return null;

        case AuthStatus.unauthenticated:
          // 인증 필요 — 인증 화면으로
          if (isAuthPage) return null;
          return "/onboarding/auth";

        case AuthStatus.emailVerificationRequired:
          // 이메일 인증은 S-16 가입 화면 안 인라인 영역으로 편입됐다(명세 §14).
          // 링크 인증만 남은 구계정이 로그인에서 403을 받은 경우에만 여기 온다.
          if (path.startsWith("/onboarding/email-verification")) return null;
          if (path == "/onboarding/auth") return null;
          final email = authState.email ?? "";
          return "/onboarding/email-verification?email=${Uri.encodeComponent(email)}";

        case AuthStatus.consentRequired:
          // 가드 2 — consentRequired가 빌 때까지 탈출 불가(§1.3).
          if (isConsentPage) return null;
          return "/onboarding/consent";

        case AuthStatus.onboarding:
          // 가드 3 — 온보딩 미완료면 마지막 미완료 단계로 교체한다.
          final isOnboardingFlow =
              (path.startsWith("/onboarding/") &&
                  !isAuthPage &&
                  !isConsentPage) ||
              (path == "/calendar/sync" &&
                  state.uri.queryParameters["onboarding"] == "true");
          if (isOnboardingFlow) return null;
          // 재개 지점은 서버가 판정한다(GET /me/onboarding · bootstrap gate).
          // 서버가 단계를 안 주면 온보딩 첫 화면으로 보낸다.
          return authState.onboardingRoute ?? "/onboarding/prep-time";

        case AuthStatus.authenticated:
          // cold start에서 유효한 지도 draft가 복원되면 사용자가 작성 중이던
          // 일정 폼으로 이어간다. 복원 완료 전 null을 보고 홈으로 보내지 않는다.
          if (path == "/splash") {
            final draftState = ref.read(mapDraftEventProvider);
            if (draftState.isLoading) return null;
            if (draftState.hasValue && draftState.value != null) {
              return "/events/create-from-map";
            }
            return "/home";
          }
          // 인증 완료 — 나머지 인증/온보딩 화면에서는 홈으로
          if (path == "/onboarding/auth" ||
              isConsentPage ||
              path.startsWith("/onboarding/email-verification")) {
            return "/home";
          }
          return null;
      }
    },
    routes: buildAppRoutes(ref),
  );
});

/// route table을 `appRouterProvider`에서 분리해 둔다 — production route가
/// 빠지거나 오타 나는 회귀를 잡으려면 테스트가 이 리스트를 그대로 써서
/// GoRouter를 만들어야 하는데, `appRouterProvider`는 redirect가
/// `authNotifierProvider`/`mapDraftEventProvider`를 즉시 구독해서 테스트
/// 하네스 부담이 크다. 이 함수는 온보딩 프라이밍 화면의 `onAllow`/`onSkip`
/// 콜백 안에서만 `ref`를 지연 참조하므로, route 목록을 만드는 시점에는
/// 저 provider들을 초기화하지 않는다.
List<RouteBase> buildAppRoutes(Ref ref) => [
  // ─── 스플래시 (세션 확인 중) ─────────────────────────────────
  GoRoute(path: "/splash", builder: (c, s) => const SplashScreen()),

  // ─── 온보딩 ──────────────────────────────────────────────────
  GoRoute(path: "/onboarding/auth", builder: (c, s) => const AuthScreen()),
  GoRoute(
    path: "/onboarding/consent",
    builder: (c, s) => const ConsentScreen(),
  ),
  GoRoute(
    path: "/onboarding/email-verification",
    builder: (c, s) =>
        EmailVerificationScreen(email: s.uri.queryParameters["email"] ?? ""),
  ),
  GoRoute(
    path: "/onboarding/signup-complete",
    builder: (c, s) => const SignupCompleteScreen(),
  ),
  GoRoute(
    path: "/onboarding/prep-time",
    builder: (c, s) => const PrepTimeEntryScreen(),
  ),
  GoRoute(
    path: "/onboarding/places",
    builder: (c, s) => const PlaceRegistrationScreen(isOnboarding: true),
  ),
  GoRoute(
    path: "/onboarding/wellness",
    builder: (c, s) => const WellnessOnboardingScreen(),
  ),
  GoRoute(
    path: "/onboarding/complete",
    builder: (c, s) => const OnboardingCompleteScreen(),
  ),
  GoRoute(
    path: "/onboarding/password-reset",
    builder: (c, s) => const PasswordResetScreen(),
  ),
  // S-21 약관 본문 (§6.1 /terms/:key, key = tos/privacy/location/marketing)
  GoRoute(
    path: "/terms/:key",
    builder: (c, s) {
      final key = s.pathParameters["key"]!;
      // 명세의 라우트 key(tos)와 서버 consentType(terms)이 다르다.
      final consentType = key == "tos" ? "terms" : key;
      return ConsentDetailScreen(
        consentType: consentType,
        title: _consentTitles[consentType] ?? "약관",
      );
    },
  ),
  GoRoute(
    path: "/onboarding/priming/notification",
    builder: (c, s) => PermissionPrimingScreen(
      type: PermissionPrimingType.notification,
      onAllow: () async {
        final status = await PermissionService.instance.requestNotification();
        if (!c.mounted) return;
        if (!status.isGranted && !status.isLimited) {
          await PermissionService.instance.showRationale(
            c,
            PermissionRationaleType.notification,
          );
        }
        // 알림은 §4.1 프라이밍 3종의 마지막이다. 다음은 S-05 웰니스.
        await ref
            .read(authNotifierProvider.notifier)
            .advanceOnboarding("wellness");
        if (c.mounted) c.go("/onboarding/wellness");
      },
      onSkip: () async {
        await ref
            .read(authNotifierProvider.notifier)
            .advanceOnboarding("wellness");
        if (c.mounted) c.go("/onboarding/wellness");
      },
    ),
  ),
  GoRoute(
    path: "/onboarding/priming/location",
    builder: (c, s) => PermissionPrimingScreen(
      type: PermissionPrimingType.location,
      onAllow: () async {
        final status = await PermissionService.instance.requestLocation();
        if (!c.mounted) return;
        if (!status.isGranted) {
          await PermissionService.instance.showRationale(
            c,
            PermissionRationaleType.location,
          );
        }
        if (c.mounted) c.go("/onboarding/priming/notification");
      },
      onSkip: () async {
        c.go("/onboarding/priming/notification");
      },
    ),
  ),
  GoRoute(
    path: "/onboarding/priming/calendar",
    builder: (c, s) => PermissionPrimingScreen(
      type: PermissionPrimingType.calendar,
      onAllow: () async {
        if (c.mounted) c.push("/calendar/sync?onboarding=true");
      },
      onSkip: () async {
        // 프라이밍 3종은 서버에 permissions 한 단계로만 기록한다.
        await ref
            .read(authNotifierProvider.notifier)
            .advanceOnboarding("permissions");
        if (c.mounted) c.go("/onboarding/priming/location");
      },
    ),
  ),

  // ─── 기능 화면 (인증 필요) ───────────────────────────────────
  GoRoute(
    path: "/notifications/today",
    builder: (c, s) => const NotificationLogScreen(),
  ),
  GoRoute(
    path: "/settings/wellness-prefs",
    builder: (c, s) => const WellnessPrefsScreen(),
  ),
  GoRoute(
    path: "/summary/daily",
    builder: (c, s) => const DailySummaryScreen(),
  ),
  GoRoute(path: "/weather", builder: (c, s) => const WeatherDetailScreen()),
  GoRoute(
    path: "/places/manage",
    builder: (c, s) => const PlaceRegistrationScreen(),
  ),
  GoRoute(
    path: "/plans/:planId/routes",
    builder: (c, s) => RouteSelectionScreen(
      planId: s.pathParameters["planId"]!,
      eventId: s.uri.queryParameters["eventId"]!,
    ),
  ),
  GoRoute(
    path: "/events/create-from-map",
    builder: (c, s) => const EventFormScreen(fromMap: true),
  ),
  GoRoute(path: "/search/place", builder: (c, s) => const PlaceSearchScreen()),
  GoRoute(path: "/calendar/new", builder: (c, s) => const EventFormScreen()),
  // S-41 캘린더 연동 관리 (§6.1 /calendar/connections). 기존 /calendar/sync는
  // 온보딩 중 연결 단계가 계속 쓴다.
  GoRoute(
    path: "/calendar/connections",
    builder: (c, s) => const CalendarSyncScreen(),
  ),
  GoRoute(
    path: "/calendar/sync",
    builder: (c, s) => CalendarSyncScreen(
      isOnboarding: s.uri.queryParameters["onboarding"] == "true",
    ),
  ),
  GoRoute(
    path: "/calendar/weekly-report",
    builder: (c, s) => WeeklyReportScreen(
      initialDate: DateTime.tryParse(s.uri.queryParameters["date"] ?? ""),
    ),
  ),

  // ─── DTL-01 일정 상세 ─────────────────────────────────────
  GoRoute(
    path: "/events/:eventId",
    builder: (c, s) => EventDetailScreen(eventId: s.pathParameters["eventId"]!),
  ),

  // ─── PRF 프로필 하위 ──────────────────────────────────────
  GoRoute(path: "/profile/account", builder: (c, s) => const AccountScreen()),
  GoRoute(path: "/profile/withdraw", builder: (c, s) => const WithdrawScreen()),
  GoRoute(
    path: "/profile/prep",
    builder: (c, s) => const PrepTimeEntryScreen(isOnboarding: false),
  ),
  GoRoute(
    path: "/profile/notifications",
    builder: (c, s) => const NotificationSettingsScreen(),
  ),
  GoRoute(
    path: "/profile/permissions",
    builder: (c, s) => const PermissionsScreen(),
  ),
  GoRoute(
    path: "/profile/personalization",
    builder: (c, s) => const PersonalizationScreen(),
  ),
  GoRoute(
    path: "/profile/data",
    builder: (c, s) => const DataManagementScreen(),
  ),
  GoRoute(
    path: "/profile/change-password",
    builder: (c, s) => const ChangePasswordScreen(),
  ),
  GoRoute(
    path: "/profile/change-email",
    builder: (c, s) => const ChangeEmailScreen(),
  ),
  GoRoute(
    path: "/profile/providers",
    builder: (c, s) => const ProvidersScreen(),
  ),
  GoRoute(path: "/profile/sessions", builder: (c, s) => const SessionsScreen()),
  GoRoute(path: "/map/bookmarks", builder: (c, s) => const BookmarksScreen()),

  // ─── 메인 4탭 (화면설계서 확정: 캘린더·홈·지도·프로필) ────
  StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => MainTabShell(shell: shell),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(path: "/calendar", builder: (c, s) => const CalendarScreen()),
        ],
      ),
      StatefulShellBranch(
        routes: [GoRoute(path: "/home", builder: (c, s) => const HomeScreen())],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: "/map",
            builder: (c, s) => MapScreen(
              initialDestName: s.uri.queryParameters["destName"],
              initialDestLat: double.tryParse(
                s.uri.queryParameters["destLat"] ?? "",
              ),
              initialDestLng: double.tryParse(
                s.uri.queryParameters["destLng"] ?? "",
              ),
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(path: "/profile", builder: (c, s) => const ProfileScreen()),
        ],
      ),
    ],
  ),
];

// ─── 메인 탭 셸 ───────────────────────────────────────────────────
/// ensom_prototype.html `.tabbar` — 화면 하단에 살짝 띄운 알약 모양
/// 탭바(좌우 26px, 아래 16px 여백, 완전히 둥근 모서리, 옅은 그림자).
/// 기본 Material BottomNavigationBar(꽉 찬 사각 바)와는 모양이 달라서
/// 직접 그린다.
class MainTabShell extends StatelessWidget {
  const MainTabShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(26, 0, 26, 16),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: EnsomColors.surface2,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: EnsomColors.ink.withValues(alpha: .12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          // 아이콘을 리스트에 넣고 인덱스로 꺼내 쓰면 Flutter 웹 릴리스
          // 빌드의 아이콘 트리쉐이커가 "실제로 쓰인다"는 걸 정적으로
          // 못 찾아서 폰트에서 잘라내 버린다(Icons.home_outlined가 이
          // 화면에서만, 그것도 간접 참조로만 쓰이다가 실제로 이렇게
          // 사라졌었다). 그래서 4개를 각각 리터럴로 직접 나열한다.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TabBarItem(
                icon: Icons.calendar_today_outlined,
                label: "캘린더",
                selected: shell.currentIndex == 0,
                onTap: () => shell.goBranch(0),
              ),
              _TabBarItem(
                icon: Icons.home_outlined,
                label: "홈",
                selected: shell.currentIndex == 1,
                onTap: () => shell.goBranch(1),
              ),
              _TabBarItem(
                icon: Icons.map_outlined,
                label: "지도",
                selected: shell.currentIndex == 2,
                onTap: () => shell.goBranch(2),
              ),
              _TabBarItem(
                icon: Icons.person_outline,
                label: "프로필",
                selected: shell.currentIndex == 3,
                onTap: () => shell.goBranch(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBarItem extends StatelessWidget {
  const _TabBarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? EnsomColors.ink : EnsomColors.inkFaint;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
