import "dart:async";

import "package:ensom/core/local_notification_service.dart";
import "package:ensom/models/event.dart";
import "package:ensom/repository/ensom_repository.dart";
import "package:ensom/repository/providers.dart";
import "package:ensom/screens/detail/event_detail_screen.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";

class _DeletingRepo implements EnsomRepository {
  final deleteCompleter = Completer<void>();
  int deleteCalls = 0;

  @override
  Future<void> deleteEvent(String eventId) {
    deleteCalls++;
    return deleteCompleter.future;
  }

  @override
  Future<Event> fetchEvent(String eventId) => Completer<Event>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NotificationService implements LocalNotificationService {
  final cancelCompleter = Completer<void>();
  final cancelledEventIds = <String>[];

  @override
  Future<void> cancelPlanNotifications({required String eventId}) {
    cancelledEventIds.add(eventId);
    return cancelCompleter.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<void> _openDetailAndDelete(
  WidgetTester tester, {
  required EnsomRepository repo,
  required LocalNotificationService notifications,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push("/events/event-1"),
            child: const Text("open"),
          ),
        ),
      ),
      GoRoute(
        path: "/events/:eventId",
        builder: (context, state) =>
            EventDetailScreen(eventId: state.pathParameters["eventId"]!),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ensomRepositoryProvider.overrideWithValue(repo),
        localNotificationServiceProvider.overrideWithValue(notifications),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.tap(find.text("open"));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byType(PopupMenuItem<String>).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byType(TextButton).last);
  await tester.pump();
}

void main() {
  testWidgets(
    "delete runs once, waits for notification cancellation, and pops once",
    (tester) async {
      final repo = _DeletingRepo();
      final notifications = _NotificationService();
      await _openDetailAndDelete(
        tester,
        repo: repo,
        notifications: notifications,
      );

      expect(repo.deleteCalls, 1);
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        isFalse,
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pump();
      expect(repo.deleteCalls, 1);

      repo.deleteCompleter.complete();
      await tester.pump();
      expect(notifications.cancelledEventIds, ["event-1"]);
      expect(find.byType(EventDetailScreen), findsOneWidget);

      notifications.cancelCompleter.complete();
      await tester.pumpAndSettle();
      expect(find.text("open"), findsOneWidget);
      expect(repo.deleteCalls, 1);
    },
  );

  testWidgets(
    "server delete succeeding is authoritative even if notification cancel fails",
    (tester) async {
      // P2 회귀: 알림 취소가 실패해도 이미 성공한 서버 삭제를 "실패"로
      // 되돌리면 안 된다 — 화면은 정상적으로 닫혀야 한다.
      final repo = _DeletingRepo();
      final notifications = _NotificationService();
      await _openDetailAndDelete(
        tester,
        repo: repo,
        notifications: notifications,
      );

      repo.deleteCompleter.complete();
      await tester.pump();
      notifications.cancelCompleter.completeError(
        Exception("platform channel error"),
      );
      await tester.pumpAndSettle();

      expect(find.text("open"), findsOneWidget);
      expect(repo.deleteCalls, 1);
    },
  );

  testWidgets(
    "leaving the screen mid-delete still finishes notification cancel and keeps the in-flight lock",
    (tester) async {
      // P2 회귀: 삭제 중 뒤로가면 화면(WidgetRef)이 dispose되더라도,
      // EventDeletionController는 provider 자신의 Ref로 살아남아 후처리를
      // 끝까지 마쳐야 하고, 같은 일정으로 재진입하면 여전히 진행 중으로
      // 보여야 한다(중복 DELETE 방지).
      final repo = _DeletingRepo();
      final notifications = _NotificationService();
      late GoRouter router;
      router = GoRouter(
        routes: [
          GoRoute(
            path: "/",
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.push("/events/event-1"),
                child: const Text("open"),
              ),
            ),
          ),
          GoRoute(
            path: "/events/:eventId",
            builder: (context, state) =>
                EventDetailScreen(eventId: state.pathParameters["eventId"]!),
          ),
        ],
      );
      addTearDown(router.dispose);

      final container = ProviderContainer(
        overrides: [
          ensomRepositoryProvider.overrideWithValue(repo),
          localNotificationServiceProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text("open"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(PopupMenuItem<String>).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(TextButton).last);
      await tester.pump();
      expect(repo.deleteCalls, 1);

      // 서버 DELETE가 아직 pending인 상태에서 뒤로가기 — 화면이 dispose된다.
      router.go("/");
      await tester.pumpAndSettle();
      expect(find.text("open"), findsOneWidget);

      // 같은 일정으로 재진입해도, 첫 DELETE가 아직 진행 중이라는 잠금이
      // 살아있어야 한다(EventDeletionController가 provider 수명에 묶여
      // keepAlive로 살아남았기 때문). 메뉴가 비활성 상태로 보이고, 삭제를
      // 다시 시도해도 호출 수가 늘지 않는다.
      await tester.tap(find.text("open"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        isFalse,
      );

      // 첫 DELETE와 알림 취소가 이제 완료된다 — 화면이 없어도 후처리가
      // 끝까지 실행돼야 한다. (eventDetailProvider의 fetchEvent가 이
      // 테스트에서 영영 resolve되지 않아 상세 화면엔 계속 로딩
      // 스피너가 떠 있으므로, pumpAndSettle 대신 pump를 쓴다.)
      repo.deleteCompleter.complete();
      notifications.cancelCompleter.complete();
      await tester.pump();
      await tester.pump();
      expect(notifications.cancelledEventIds, ["event-1"]);
      expect(repo.deleteCalls, 1);
    },
  );
}
