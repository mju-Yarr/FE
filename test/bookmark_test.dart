import "package:ensom/models/bookmark.dart";
import "package:flutter_test/flutter_test.dart";

/// 북마크·최근 목적지는 좌표로 서로를 알아본다. 파싱이나 비교가 틀리면
/// 최근 목적지의 별이 항상 꺼져 보이거나 북마크가 중복 생성된다.
void main() {
  test("북마크를 서버 필드 그대로 읽는다", () {
    final bookmark = Bookmark.fromJson({
      "bookmarkId": "b1",
      "placeName": "강남역",
      "address": "서울 강남구",
      "lat": 37.498,
      "lng": 127.027,
      "folder": "자주",
      "sortOrder": 3,
      "createdAt": "2026-08-20T00:00:00Z",
      "updatedAt": "2026-08-21T00:00:00Z",
    });

    expect(bookmark.bookmarkId, "b1");
    expect(bookmark.placeName, "강남역");
    expect(bookmark.folder, "자주");
    expect(bookmark.sortOrder, 3);
    expect(bookmark.lat, closeTo(37.498, 0.000001));
  });

  test("폴더·주소가 없는 북마크도 읽는다", () {
    final bookmark = Bookmark.fromJson({
      "bookmarkId": "b1",
      "placeName": "강남역",
      "address": null,
      "lat": 37.498,
      "lng": 127.027,
      "folder": null,
      "sortOrder": 0,
      "createdAt": null,
      "updatedAt": null,
    });

    expect(bookmark.folder, isNull);
    expect(bookmark.address, isNull);
    expect(bookmark.createdAt, isNull);
  });

  test("BE가 소수 6자리로 돌려줘도 좌표를 double로 읽는다", () {
    // decimal(9,6)이라 37.498000처럼 온다. num으로 받아야 int/double 양쪽에
    // 안전하다.
    final bookmark = Bookmark.fromJson({
      "bookmarkId": "b1",
      "placeName": "서울시청",
      "lat": 37.566000,
      "lng": 127,
      "sortOrder": 0,
    });

    expect(bookmark.lat, closeTo(37.566, 0.000001));
    expect(bookmark.lng, closeTo(127.0, 0.000001));
  });

  test("최근 목적지의 bookmarked를 서버 판정 그대로 읽는다", () {
    final recent = RecentDestination.fromJson({
      "recentDestinationId": "r1",
      "placeName": "강남역",
      "address": "서울 강남구",
      "lat": 37.498,
      "lng": 127.027,
      "bookmarked": true,
      "lastUsedAt": "2026-08-22T01:00:00Z",
    });

    expect(recent.bookmarked, isTrue);
    expect(recent.placeName, "강남역");
  });

  test("bookmarked가 빠지면 북마크가 아닌 것으로 본다", () {
    final recent = RecentDestination.fromJson({
      "recentDestinationId": "r1",
      "placeName": "강남역",
      "lat": 37.498,
      "lng": 127.027,
      "lastUsedAt": "2026-08-22T01:00:00Z",
    });

    // 없는 값을 별이 켜진 것으로 오해하면 해제할 북마크를 못 찾는다.
    expect(recent.bookmarked, isFalse);
  });
}
