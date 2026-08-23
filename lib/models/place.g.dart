// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Place _$PlaceFromJson(Map<String, dynamic> json) => _Place(
  placeId: json['placeId'] as String,
  placeType: json['placeType'] as String,
  placeName: json['placeName'] as String,
  address: json['address'] as String,
  lat: (json['lat'] as num).toDouble(),
  lng: (json['lng'] as num).toDouble(),
  isPrimary: json['isPrimary'] as bool? ?? false,
);

Map<String, dynamic> _$PlaceToJson(_Place instance) => <String, dynamic>{
  'placeId': instance.placeId,
  'placeType': instance.placeType,
  'placeName': instance.placeName,
  'address': instance.address,
  'lat': instance.lat,
  'lng': instance.lng,
  'isPrimary': instance.isPrimary,
};
