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

void main() {
  testWidgets(
    "delete runs once, waits for notification cancellation, and pops once",
    (tester) async {
      final repo = _DeletingRepo();
      final notifications = _NotificationService();
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
}
