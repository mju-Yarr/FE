import "package:ensom/models/event.dart";
import "package:ensom/models/place.dart";
import "package:ensom/repository/ensom_repository.dart";
import "package:ensom/screens/calendar/event_form_screen.dart";
import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";

class _OriginRepo implements EnsomRepository {
  _OriginRepo(this.places, {this.fetchError});

  final List<Place> places;
  final Object? fetchError;
  int fetchPlacesCalls = 0;

  @override
  Future<List<Place>> fetchPlaces() async {
    fetchPlacesCalls++;
    if (fetchError != null) throw fetchError!;
    return places;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Place _place(String placeId, {bool isPrimary = false}) => Place(
  placeId: placeId,
  placeType: "home",
  placeName: placeId,
  address: "서울",
  lat: 37.1,
  lng: 127.1,
  isPrimary: isPrimary,
);

void main() {
  test("일반 물리 일정은 primary 장소를 우선한다", () async {
    final repo = _OriginRepo(const [
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
    ]);

    final result = await resolveEventOriginPlaceId(
      repository: repo,
      locationState: LocationState.requiredResolved,
      hasMapDraft: false,
    );

    expect(result, "primary");
    expect(repo.fetchPlacesCalls, 1);
  });

  test("일반 물리 일정은 primary가 없으면 첫 장소를 선택한다", () async {
    final repo = _OriginRepo([_place("first"), _place("second")]);

    final result = await resolveEventOriginPlaceId(
      repository: repo,
      locationState: LocationState.requiredResolved,
      hasMapDraft: false,
    );

    expect(result, "first");
    expect(repo.fetchPlacesCalls, 1);
  });

  test("일반 물리 일정은 저장 장소가 없으면 출발지를 비운다", () async {
    final repo = _OriginRepo(const []);

    final result = await resolveEventOriginPlaceId(
      repository: repo,
      locationState: LocationState.requiredResolved,
      hasMapDraft: false,
    );

    expect(result, isNull);
    expect(repo.fetchPlacesCalls, 1);
  });

  test("일반 물리 일정은 장소 조회 실패에도 출발지를 비운다", () async {
    final repo = _OriginRepo(const [], fetchError: StateError("network"));
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    addTearDown(() => debugPrint = originalDebugPrint);

    final result = await resolveEventOriginPlaceId(
      repository: repo,
      locationState: LocationState.requiredResolved,
      hasMapDraft: false,
    );

    expect(result, isNull);
    expect(repo.fetchPlacesCalls, 1);
  });

  test("온라인 일정은 장소를 조회하지 않는다", () async {
    final repo = _OriginRepo(const []);

    final result = await resolveEventOriginPlaceId(
      repository: repo,
      locationState: LocationState.notRequired,
      hasMapDraft: false,
    );

    expect(result, isNull);
    expect(repo.fetchPlacesCalls, 0);
  });

  test("미정 일정은 장소를 조회하지 않는다", () async {
    final repo = _OriginRepo(const []);

    final result = await resolveEventOriginPlaceId(
      repository: repo,
      locationState: LocationState.undecided,
      hasMapDraft: false,
    );

    expect(result, isNull);
    expect(repo.fetchPlacesCalls, 0);
  });

  test("지도 초안은 초안 출발지를 우선하고 장소를 조회하지 않는다", () async {
    final repo = _OriginRepo(const []);

    final result = await resolveEventOriginPlaceId(
      repository: repo,
      locationState: LocationState.requiredResolved,
      hasMapDraft: true,
      draftOriginPlaceId: "draft",
    );

    expect(result, "draft");
    expect(repo.fetchPlacesCalls, 0);
  });

  test("출발지가 없는 지도 초안은 장소를 조회하지 않는다", () async {
    final repo = _OriginRepo(const []);

    final result = await resolveEventOriginPlaceId(
      repository: repo,
      locationState: LocationState.requiredResolved,
      hasMapDraft: true,
    );

    expect(result, isNull);
    expect(repo.fetchPlacesCalls, 0);
  });
}
