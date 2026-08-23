import 'package:freezed_annotation/freezed_annotation.dart';

part 'place.freezed.dart';
part 'place.g.dart';

/// SET-01. ERD `USER_PLACE`(place_id, place_type, place_name, address,
/// lat, lng, is_primary) 그대로 반영 — 이전 필드(label/radiusM/
/// kakaoPlaceId)는 실제 스키마에 없던 값이었다. 지오펜스 반경은
/// 사용자가 정하지 않는다(TRD D7 — 출발지 150m 고정, 목적지는
/// 장소 유형별 100/150/200m 정책값). placeType 고정 목록은 문서에
/// 명시돼 있지 않아 "home"(API 예시로 확인) 외에 "work"·"other"로
/// 잠정 사용한다.
@freezed
abstract class Place with _$Place {
  const factory Place({
    required String placeId,
    required String placeType,
    required String placeName,
    required String address,
    required double lat,
    required double lng,
    @Default(false) bool isPrimary,
  }) = _Place;

  factory Place.fromJson(Map<String, dynamic> json) => _$PlaceFromJson(json);
}
