import "package:ensom/models/event.dart";
import "package:ensom/models/plan.dart";
import "package:ensom/providers/calendar_providers.dart";
import "package:ensom/repository/ensom_repository.dart";
import "package:ensom/repository/providers.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

class _EventRepo implements EnsomRepository {
  _EventRepo(this.events);

  final List<Event> events;

  @override
  Future<List<Event>> fetchEvents({
    required DateTime from,
    required DateTime to,
  }) async => events;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Event _event(String id, EventLifecycleStatus status) => Event(
  eventId: id,
  displayName: id,
  startsAt: DateTime.utc(2026, 8, 24, 3),
  locationState: LocationState.notRequired,
  status: status,
);

void main() {
  test("calendar excludes soft-deleted events returned by the API", () async {
    final repo = _EventRepo([
      _event("active", EventLifecycleStatus.planned),
      _event("deleted", EventLifecycleStatus.cancelled),
    ]);
    final container = ProviderContainer(
      overrides: [ensomRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final events = await container.read(
      eventsInRangeProvider(
        EventRange(
          from: DateTime.utc(2026, 8, 1),
          to: DateTime.utc(2026, 8, 30),
        ),
      ).future,
    );

    expect(events.map((event) => event.eventId), ["active"]);
  });
}
