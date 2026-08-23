// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_wellness_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DailyWellnessSummary {

 String get summaryId;// POST /summary/daily/{summaryId}/viewed 에 필요
 String get summaryDate;// yyyy-MM-dd
 int get eventCount; int get totalOutdoorMinutes; String get outdoorSource;// 홈 wrap 카드의 "정시 도착" 칸. arrivalSampleCount가 0이면 도착 결과를
// 하나도 모르는 것이므로 0회로 표시하지 않고 칸을 감춘다.
 int get onTimeCount; int get arrivalSampleCount; DwlBand get dwlBand; String get cardScenario;// default|exposure|density|rushed|stable
 String get message;// 서버 템플릿 문구. 클라이언트가 재구성하지 않는다
 bool get isViewed; int? get dwlScore;
/// Create a copy of DailyWellnessSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyWellnessSummaryCopyWith<DailyWellnessSummary> get copyWith => _$DailyWellnessSummaryCopyWithImpl<DailyWellnessSummary>(this as DailyWellnessSummary, _$identity);

  /// Serializes this DailyWellnessSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyWellnessSummary&&(identical(other.summaryId, summaryId) || other.summaryId == summaryId)&&(identical(other.summaryDate, summaryDate) || other.summaryDate == summaryDate)&&(identical(other.eventCount, eventCount) || other.eventCount == eventCount)&&(identical(other.totalOutdoorMinutes, totalOutdoorMinutes) || other.totalOutdoorMinutes == totalOutdoorMinutes)&&(identical(other.outdoorSource, outdoorSource) || other.outdoorSource == outdoorSource)&&(identical(other.onTimeCount, onTimeCount) || other.onTimeCount == onTimeCount)&&(identical(other.arrivalSampleCount, arrivalSampleCount) || other.arrivalSampleCount == arrivalSampleCount)&&(identical(other.dwlBand, dwlBand) || other.dwlBand == dwlBand)&&(identical(other.cardScenario, cardScenario) || other.cardScenario == cardScenario)&&(identical(other.message, message) || other.message == message)&&(identical(other.isViewed, isViewed) || other.isViewed == isViewed)&&(identical(other.dwlScore, dwlScore) || other.dwlScore == dwlScore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,summaryId,summaryDate,eventCount,totalOutdoorMinutes,outdoorSource,onTimeCount,arrivalSampleCount,dwlBand,cardScenario,message,isViewed,dwlScore);

@override
String toString() {
  return 'DailyWellnessSummary(summaryId: $summaryId, summaryDate: $summaryDate, eventCount: $eventCount, totalOutdoorMinutes: $totalOutdoorMinutes, outdoorSource: $outdoorSource, onTimeCount: $onTimeCount, arrivalSampleCount: $arrivalSampleCount, dwlBand: $dwlBand, cardScenario: $cardScenario, message: $message, isViewed: $isViewed, dwlScore: $dwlScore)';
}


}

/// @nodoc
abstract mixin class $DailyWellnessSummaryCopyWith<$Res>  {
  factory $DailyWellnessSummaryCopyWith(DailyWellnessSummary value, $Res Function(DailyWellnessSummary) _then) = _$DailyWellnessSummaryCopyWithImpl;
@useResult
$Res call({
 String summaryId, String summaryDate, int eventCount, int totalOutdoorMinutes, String outdoorSource, int onTimeCount, int arrivalSampleCount, DwlBand dwlBand, String cardScenario, String message, bool isViewed, int? dwlScore
});




}
/// @nodoc
class _$DailyWellnessSummaryCopyWithImpl<$Res>
    implements $DailyWellnessSummaryCopyWith<$Res> {
  _$DailyWellnessSummaryCopyWithImpl(this._self, this._then);

  final DailyWellnessSummary _self;
  final $Res Function(DailyWellnessSummary) _then;

/// Create a copy of DailyWellnessSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? summaryId = null,Object? summaryDate = null,Object? eventCount = null,Object? totalOutdoorMinutes = null,Object? outdoorSource = null,Object? onTimeCount = null,Object? arrivalSampleCount = null,Object? dwlBand = null,Object? cardScenario = null,Object? message = null,Object? isViewed = null,Object? dwlScore = freezed,}) {
  return _then(_self.copyWith(
summaryId: null == summaryId ? _self.summaryId : summaryId // ignore: cast_nullable_to_non_nullable
as String,summaryDate: null == summaryDate ? _self.summaryDate : summaryDate // ignore: cast_nullable_to_non_nullable
as String,eventCount: null == eventCount ? _self.eventCount : eventCount // ignore: cast_nullable_to_non_nullable
as int,totalOutdoorMinutes: null == totalOutdoorMinutes ? _self.totalOutdoorMinutes : totalOutdoorMinutes // ignore: cast_nullable_to_non_nullable
as int,outdoorSource: null == outdoorSource ? _self.outdoorSource : outdoorSource // ignore: cast_nullable_to_non_nullable
as String,onTimeCount: null == onTimeCount ? _self.onTimeCount : onTimeCount // ignore: cast_nullable_to_non_nullable
as int,arrivalSampleCount: null == arrivalSampleCount ? _self.arrivalSampleCount : arrivalSampleCount // ignore: cast_nullable_to_non_nullable
as int,dwlBand: null == dwlBand ? _self.dwlBand : dwlBand // ignore: cast_nullable_to_non_nullable
as DwlBand,cardScenario: null == cardScenario ? _self.cardScenario : cardScenario // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,isViewed: null == isViewed ? _self.isViewed : isViewed // ignore: cast_nullable_to_non_nullable
as bool,dwlScore: freezed == dwlScore ? _self.dwlScore : dwlScore // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [DailyWellnessSummary].
extension DailyWellnessSummaryPatterns on DailyWellnessSummary {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyWellnessSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyWellnessSummary() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyWellnessSummary value)  $default,){
final _that = this;
switch (_that) {
case _DailyWellnessSummary():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyWellnessSummary value)?  $default,){
final _that = this;
switch (_that) {
case _DailyWellnessSummary() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String summaryId,  String summaryDate,  int eventCount,  int totalOutdoorMinutes,  String outdoorSource,  int onTimeCount,  int arrivalSampleCount,  DwlBand dwlBand,  String cardScenario,  String message,  bool isViewed,  int? dwlScore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyWellnessSummary() when $default != null:
return $default(_that.summaryId,_that.summaryDate,_that.eventCount,_that.totalOutdoorMinutes,_that.outdoorSource,_that.onTimeCount,_that.arrivalSampleCount,_that.dwlBand,_that.cardScenario,_that.message,_that.isViewed,_that.dwlScore);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String summaryId,  String summaryDate,  int eventCount,  int totalOutdoorMinutes,  String outdoorSource,  int onTimeCount,  int arrivalSampleCount,  DwlBand dwlBand,  String cardScenario,  String message,  bool isViewed,  int? dwlScore)  $default,) {final _that = this;
switch (_that) {
case _DailyWellnessSummary():
return $default(_that.summaryId,_that.summaryDate,_that.eventCount,_that.totalOutdoorMinutes,_that.outdoorSource,_that.onTimeCount,_that.arrivalSampleCount,_that.dwlBand,_that.cardScenario,_that.message,_that.isViewed,_that.dwlScore);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String summaryId,  String summaryDate,  int eventCount,  int totalOutdoorMinutes,  String outdoorSource,  int onTimeCount,  int arrivalSampleCount,  DwlBand dwlBand,  String cardScenario,  String message,  bool isViewed,  int? dwlScore)?  $default,) {final _that = this;
switch (_that) {
case _DailyWellnessSummary() when $default != null:
return $default(_that.summaryId,_that.summaryDate,_that.eventCount,_that.totalOutdoorMinutes,_that.outdoorSource,_that.onTimeCount,_that.arrivalSampleCount,_that.dwlBand,_that.cardScenario,_that.message,_that.isViewed,_that.dwlScore);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DailyWellnessSummary implements DailyWellnessSummary {
  const _DailyWellnessSummary({required this.summaryId, required this.summaryDate, required this.eventCount, required this.totalOutdoorMinutes, required this.outdoorSource, this.onTimeCount = 0, this.arrivalSampleCount = 0, required this.dwlBand, required this.cardScenario, required this.message, this.isViewed = false, this.dwlScore});
  factory _DailyWellnessSummary.fromJson(Map<String, dynamic> json) => _$DailyWellnessSummaryFromJson(json);

@override final  String summaryId;
// POST /summary/daily/{summaryId}/viewed 에 필요
@override final  String summaryDate;
// yyyy-MM-dd
@override final  int eventCount;
@override final  int totalOutdoorMinutes;
@override final  String outdoorSource;
// 홈 wrap 카드의 "정시 도착" 칸. arrivalSampleCount가 0이면 도착 결과를
// 하나도 모르는 것이므로 0회로 표시하지 않고 칸을 감춘다.
@override@JsonKey() final  int onTimeCount;
@override@JsonKey() final  int arrivalSampleCount;
@override final  DwlBand dwlBand;
@override final  String cardScenario;
// default|exposure|density|rushed|stable
@override final  String message;
// 서버 템플릿 문구. 클라이언트가 재구성하지 않는다
@override@JsonKey() final  bool isViewed;
@override final  int? dwlScore;

/// Create a copy of DailyWellnessSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyWellnessSummaryCopyWith<_DailyWellnessSummary> get copyWith => __$DailyWellnessSummaryCopyWithImpl<_DailyWellnessSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DailyWellnessSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyWellnessSummary&&(identical(other.summaryId, summaryId) || other.summaryId == summaryId)&&(identical(other.summaryDate, summaryDate) || other.summaryDate == summaryDate)&&(identical(other.eventCount, eventCount) || other.eventCount == eventCount)&&(identical(other.totalOutdoorMinutes, totalOutdoorMinutes) || other.totalOutdoorMinutes == totalOutdoorMinutes)&&(identical(other.outdoorSource, outdoorSource) || other.outdoorSource == outdoorSource)&&(identical(other.onTimeCount, onTimeCount) || other.onTimeCount == onTimeCount)&&(identical(other.arrivalSampleCount, arrivalSampleCount) || other.arrivalSampleCount == arrivalSampleCount)&&(identical(other.dwlBand, dwlBand) || other.dwlBand == dwlBand)&&(identical(other.cardScenario, cardScenario) || other.cardScenario == cardScenario)&&(identical(other.message, message) || other.message == message)&&(identical(other.isViewed, isViewed) || other.isViewed == isViewed)&&(identical(other.dwlScore, dwlScore) || other.dwlScore == dwlScore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,summaryId,summaryDate,eventCount,totalOutdoorMinutes,outdoorSource,onTimeCount,arrivalSampleCount,dwlBand,cardScenario,message,isViewed,dwlScore);

@override
String toString() {
  return 'DailyWellnessSummary(summaryId: $summaryId, summaryDate: $summaryDate, eventCount: $eventCount, totalOutdoorMinutes: $totalOutdoorMinutes, outdoorSource: $outdoorSource, onTimeCount: $onTimeCount, arrivalSampleCount: $arrivalSampleCount, dwlBand: $dwlBand, cardScenario: $cardScenario, message: $message, isViewed: $isViewed, dwlScore: $dwlScore)';
}


}

/// @nodoc
abstract mixin class _$DailyWellnessSummaryCopyWith<$Res> implements $DailyWellnessSummaryCopyWith<$Res> {
  factory _$DailyWellnessSummaryCopyWith(_DailyWellnessSummary value, $Res Function(_DailyWellnessSummary) _then) = __$DailyWellnessSummaryCopyWithImpl;
@override @useResult
$Res call({
 String summaryId, String summaryDate, int eventCount, int totalOutdoorMinutes, String outdoorSource, int onTimeCount, int arrivalSampleCount, DwlBand dwlBand, String cardScenario, String message, bool isViewed, int? dwlScore
});




}
/// @nodoc
class __$DailyWellnessSummaryCopyWithImpl<$Res>
    implements _$DailyWellnessSummaryCopyWith<$Res> {
  __$DailyWellnessSummaryCopyWithImpl(this._self, this._then);

  final _DailyWellnessSummary _self;
  final $Res Function(_DailyWellnessSummary) _then;

/// Create a copy of DailyWellnessSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? summaryId = null,Object? summaryDate = null,Object? eventCount = null,Object? totalOutdoorMinutes = null,Object? outdoorSource = null,Object? onTimeCount = null,Object? arrivalSampleCount = null,Object? dwlBand = null,Object? cardScenario = null,Object? message = null,Object? isViewed = null,Object? dwlScore = freezed,}) {
  return _then(_DailyWellnessSummary(
summaryId: null == summaryId ? _self.summaryId : summaryId // ignore: cast_nullable_to_non_nullable
as String,summaryDate: null == summaryDate ? _self.summaryDate : summaryDate // ignore: cast_nullable_to_non_nullable
as String,eventCount: null == eventCount ? _self.eventCount : eventCount // ignore: cast_nullable_to_non_nullable
as int,totalOutdoorMinutes: null == totalOutdoorMinutes ? _self.totalOutdoorMinutes : totalOutdoorMinutes // ignore: cast_nullable_to_non_nullable
as int,outdoorSource: null == outdoorSource ? _self.outdoorSource : outdoorSource // ignore: cast_nullable_to_non_nullable
as String,onTimeCount: null == onTimeCount ? _self.onTimeCount : onTimeCount // ignore: cast_nullable_to_non_nullable
as int,arrivalSampleCount: null == arrivalSampleCount ? _self.arrivalSampleCount : arrivalSampleCount // ignore: cast_nullable_to_non_nullable
as int,dwlBand: null == dwlBand ? _self.dwlBand : dwlBand // ignore: cast_nullable_to_non_nullable
as DwlBand,cardScenario: null == cardScenario ? _self.cardScenario : cardScenario // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,isViewed: null == isViewed ? _self.isViewed : isViewed // ignore: cast_nullable_to_non_nullable
as bool,dwlScore: freezed == dwlScore ? _self.dwlScore : dwlScore // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
