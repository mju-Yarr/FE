/// BE `BookmarkResponse` — GET/POST/PATCH /v1/me/bookmarks.
class Bookmark {
  const Bookmark({
    required this.bookmarkId,
    required this.placeName,
    this.address,
    required this.lat,
    required this.lng,
    this.folder,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
    bookmarkId: json["bookmarkId"] as String,
    placeName: json["placeName"] as String,
    address: json["address"] as String?,
    // BE는 decimal(9,6)/decimal(10,6)이라 JSON에서 num으로 온다.
    lat: (json["lat"] as num).toDouble(),
    lng: (json["lng"] as num).toDouble(),
    folder: json["folder"] as String?,
    sortOrder: (json["sortOrder"] as num?)?.toInt() ?? 0,
    createdAt: json["createdAt"] == null
        ? null
        : DateTime.parse(json["createdAt"] as String),
    updatedAt: json["updatedAt"] == null
        ? null
        : DateTime.parse(json["updatedAt"] as String),
  );

  final String bookmarkId;
  final String placeName;
  final String? address;
  final double lat;
  final double lng;

  /// 폴더 미지정이면 null. S-30 폴더 세그먼트가 이 값으로 필터링한다.
  final String? folder;

  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// BE `RecentDestinationResponse` — GET /v1/me/recent-destinations.
class RecentDestination {
  const RecentDestination({
    required this.recentDestinationId,
    required this.placeName,
    this.address,
    required this.lat,
    required this.lng,
    required this.bookmarked,
    required this.lastUsedAt,
  });

  factory RecentDestination.fromJson(Map<String, dynamic> json) =>
      RecentDestination(
        recentDestinationId: json["recentDestinationId"] as String,
        placeName: json["placeName"] as String,
        address: json["address"] as String?,
        lat: (json["lat"] as num).toDouble(),
        lng: (json["lng"] as num).toDouble(),
        // 같은 좌표의 북마크가 있는지 서버가 판정해서 준다. S-08 최근 목적지
        // 행의 별 아이콘이 이 값을 쓴다.
        bookmarked: json["bookmarked"] as bool? ?? false,
        lastUsedAt: DateTime.parse(json["lastUsedAt"] as String),
      );

  final String recentDestinationId;
  final String placeName;
  final String? address;
  final double lat;
  final double lng;
  final bool bookmarked;
  final DateTime lastUsedAt;
}
