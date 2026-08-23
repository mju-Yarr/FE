import "package:ensom/models/bookmark.dart";
import "package:ensom/models/calendar_connection.dart";
import "package:ensom/models/event.dart";
import "package:ensom/models/place.dart";
import "package:ensom/repository/ensom_repository.dart";
import "package:ensom/repository/providers.dart";
import "package:ensom/screens/calendar/event_form_screen.dart";
import "package:ensom/widgets/ensom/ensom_pill_button.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";

class _SavingRepo implements EnsomRepository {
  _SavingRepo({required this.places, this.bookmarks = const []});

  final List<Place> places;
  final List<Bookmark> bookmarks;
  int fetchPlacesCalls = 0;
  int createEventCalls = 0;
  Event? createdEvent;
  String? createdOriginPlaceId;

  @override
  Future<List<Place>> fetchPlaces() async {
    fetchPlacesCalls++;
    return places;
  }

  @override
  Future<List<Bookmark>> fetchBookmarks({String? folder}) async => bookmarks;

  @override
  Future<List<CalendarConnection>> fetchCalendarConnections() async => const [];

  @override
  Future<Event> createEvent(
    Event event, {
    String? originPlaceId,
    String? selectedRouteOptionId,
    String? writeToCalendarSourceId,
  }) async {
    createEventCalls++;
    createdEvent = event;
    createdOriginPlaceId = originPlaceId;
    return event.copyWith(eventId: "created");
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<void> _pumpForm(WidgetTester tester, _SavingRepo repository) async {
  tester.view.physicalSize = const Size(834, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: "/events/new",
    routes: [
      GoRoute(path: "/events/new", builder: (_, _) => const EventFormScreen()),
      GoRoute(
        path: "/events/:eventId",
        builder: (_, _) => const SizedBox.shrink(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [ensomRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterTitle(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, "회의");
  await tester.pump();
}

Future<void> _save(WidgetTester tester) async {
  final save = find.widgetWithText(EnsomPillButton, "저장");
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("일반 물리 일정 저장은 최종 location state의 primary 출발지를 전달한다", (
    tester,
  ) async {
    final repository = _SavingRepo(
      places: const [
        Place(
          placeId: "first",
          placeType: "work",
          placeName: "회사",
          address: "서울",
          lat: 37.1,
          lng: 127.1,
        ),
        Place(
          placeId: "primary",
          placeType: "home",
          placeName: "집",
          address: "서울",
          lat: 37.2,
          lng: 127.2,
          isPrimary: true,
        ),
      ],
      bookmarks: const [
        Bookmark(
          bookmarkId: "destination",
          placeName: "강남역",
          lat: 37.497,
          lng: 127.027,
        ),
      ],
    );
    await _pumpForm(tester, repository);

    await _enterTitle(tester);
    await tester.tap(find.text("장소 필요"));
    await tester.pump();
    final quickPick = find.text("북마크·최근에서 고르기");
    await tester.ensureVisible(quickPick);
    await tester.tap(quickPick);
    await tester.pumpAndSettle();
    await tester.tap(find.text("강남역"));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(repository.fetchPlacesCalls, 1);
    expect(repository.createEventCalls, 1);
    expect(
      repository.createdEvent!.locationState,
      LocationState.requiredResolved,
    );
    expect(repository.createdOriginPlaceId, "primary");
  });

  testWidgets("온라인 일정 저장은 장소 조회 없이 null 출발지를 전달한다", (tester) async {
    final repository = _SavingRepo(places: const []);
    await _pumpForm(tester, repository);

    await _enterTitle(tester);
    await tester.tap(find.text("장소 불필요"));
    await tester.pump();
    await _save(tester);

    expect(repository.fetchPlacesCalls, 0);
    expect(repository.createEventCalls, 1);
    expect(repository.createdEvent!.locationState, LocationState.notRequired);
    expect(repository.createdOriginPlaceId, isNull);
  });
}
