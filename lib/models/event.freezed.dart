// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Event {

 String get eventId; String? get title; String? get displayLabel; String get displayName; DateTime get startsAt; String? get timezone;// BE EventResponse.endsAt은 nullable이다 — 종료 시각 없이 만든 일정이
// 그대로 null로 내려온다.
 DateTime? get endsAt; LocationState get locationState; String? get destinationName; String? get destinationAddress; double? get destinationLat; double? get destinationLng; String? get meetingUrl; String? get eventKind; String? get calendarSourceId; EventAnchor get anchor; EventSourceType get sourceType; EventLifecycleStatus? get status; bool? get autoManageExcluded;
/// Create a copy of Event
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EventCopyWith<Event> get copyWith => _$EventCopyWithImpl<Event>(this as Event, _$identity);

  /// Serializes this Event to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Event&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.title, title) || other.title == title)&&(identical(other.displayLabel, displayLabel) || other.displayLabel == displayLabel)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.locationState, locationState) || other.locationState == locationState)&&(identical(other.destinationName, destinationName) || other.destinationName == destinationName)&&(identical(other.destinationAddress, destinationAddress) || other.destinationAddress == destinationAddress)&&(identical(other.destinationLat, destinationLat) || other.destinationLat == destinationLat)&&(identical(other.destinationLng, destinationLng) || other.destinationLng == destinationLng)&&(identical(other.meetingUrl, meetingUrl) || other.meetingUrl == meetingUrl)&&(identical(other.eventKind, eventKind) || other.eventKind == eventKind)&&(identical(other.calendarSourceId, calendarSourceId) || other.calendarSourceId == calendarSourceId)&&(identical(other.anchor, anchor) || other.anchor == anchor)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.status, status) || other.status == status)&&(identical(other.autoManageExcluded, autoManageExcluded) || other.autoManageExcluded == autoManageExcluded));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,eventId,title,displayLabel,displayName,startsAt,timezone,endsAt,locationState,destinationName,destinationAddress,destinationLat,destinationLng,meetingUrl,eventKind,calendarSourceId,anchor,sourceType,status,autoManageExcluded]);

@override
String toString() {
  return 'Event(eventId: $eventId, title: $title, displayLabel: $displayLabel, displayName: $displayName, startsAt: $startsAt, timezone: $timezone, endsAt: $endsAt, locationState: $locationState, destinationName: $destinationName, destinationAddress: $destinationAddress, destinationLat: $destinationLat, destinationLng: $destinationLng, meetingUrl: $meetingUrl, eventKind: $eventKind, calendarSourceId: $calendarSourceId, anchor: $anchor, sourceType: $sourceType, status: $status, autoManageExcluded: $autoManageExcluded)';
}


}

/// @nodoc
abstract mixin class $EventCopyWith<$Res>  {
  factory $EventCopyWith(Event value, $Res Function(Event) _then) = _$EventCopyWithImpl;
@useResult
$Res call({
 String eventId, String? title, String? displayLabel, String displayName, DateTime startsAt, String? timezone, DateTime? endsAt, LocationState locationState, String? destinationName, String? destinationAddress, double? destinationLat, double? destinationLng, String? meetingUrl, String? eventKind, String? calendarSourceId, EventAnchor anchor, EventSourceType sourceType, EventLifecycleStatus? status, bool? autoManageExcluded
});




}
/// @nodoc
class _$EventCopyWithImpl<$Res>
    implements $EventCopyWith<$Res> {
  _$EventCopyWithImpl(this._self, this._then);

  final Event _self;
  final $Res Function(Event) _then;

/// Create a copy of Event
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? eventId = null,Object? title = freezed,Object? displayLabel = freezed,Object? displayName = null,Object? startsAt = null,Object? timezone = freezed,Object? endsAt = freezed,Object? locationState = null,Object? destinationName = freezed,Object? destinationAddress = freezed,Object? destinationLat = freezed,Object? destinationLng = freezed,Object? meetingUrl = freezed,Object? eventKind = freezed,Object? calendarSourceId = freezed,Object? anchor = null,Object? sourceType = null,Object? status = freezed,Object? autoManageExcluded = freezed,}) {
  return _then(_self.copyWith(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,displayLabel: freezed == displayLabel ? _self.displayLabel : displayLabel // ignore: cast_nullable_to_non_nullable
as String?,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,locationState: null == locationState ? _self.locationState : locationState // ignore: cast_nullable_to_non_nullable
as LocationState,destinationName: freezed == destinationName ? _self.destinationName : destinationName // ignore: cast_nullable_to_non_nullable
as String?,destinationAddress: freezed == destinationAddress ? _self.destinationAddress : destinationAddress // ignore: cast_nullable_to_non_nullable
as String?,destinationLat: freezed == destinationLat ? _self.destinationLat : destinationLat // ignore: cast_nullable_to_non_nullable
as double?,destinationLng: freezed == destinationLng ? _self.destinationLng : destinationLng // ignore: cast_nullable_to_non_nullable
as double?,meetingUrl: freezed == meetingUrl ? _self.meetingUrl : meetingUrl // ignore: cast_nullable_to_non_nullable
as String?,eventKind: freezed == eventKind ? _self.eventKind : eventKind // ignore: cast_nullable_to_non_nullable
as String?,calendarSourceId: freezed == calendarSourceId ? _self.calendarSourceId : calendarSourceId // ignore: cast_nullable_to_non_nullable
as String?,anchor: null == anchor ? _self.anchor : anchor // ignore: cast_nullable_to_non_nullable
as EventAnchor,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as EventSourceType,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EventLifecycleStatus?,autoManageExcluded: freezed == autoManageExcluded ? _self.autoManageExcluded : autoManageExcluded // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [Event].
extension EventPatterns on Event {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Event value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Event() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Event value)  $default,){
final _that = this;
switch (_that) {
case _Event():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Event value)?  $default,){
final _that = this;
switch (_that) {
case _Event() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String eventId,  String? title,  String? displayLabel,  String displayName,  DateTime startsAt,  String? timezone,  DateTime? endsAt,  LocationState locationState,  String? destinationName,  String? destinationAddress,  double? destinationLat,  double? destinationLng,  String? meetingUrl,  String? eventKind,  String? calendarSourceId,  EventAnchor anchor,  EventSourceType sourceType,  EventLifecycleStatus? status,  bool? autoManageExcluded)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Event() when $default != null:
return $default(_that.eventId,_that.title,_that.displayLabel,_that.displayName,_that.startsAt,_that.timezone,_that.endsAt,_that.locationState,_that.destinationName,_that.destinationAddress,_that.destinationLat,_that.destinationLng,_that.meetingUrl,_that.eventKind,_that.calendarSourceId,_that.anchor,_that.sourceType,_that.status,_that.autoManageExcluded);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String eventId,  String? title,  String? displayLabel,  String displayName,  DateTime startsAt,  String? timezone,  DateTime? endsAt,  LocationState locationState,  String? destinationName,  String? destinationAddress,  double? destinationLat,  double? destinationLng,  String? meetingUrl,  String? eventKind,  String? calendarSourceId,  EventAnchor anchor,  EventSourceType sourceType,  EventLifecycleStatus? status,  bool? autoManageExcluded)  $default,) {final _that = this;
switch (_that) {
case _Event():
return $default(_that.eventId,_that.title,_that.displayLabel,_that.displayName,_that.startsAt,_that.timezone,_that.endsAt,_that.locationState,_that.destinationName,_that.destinationAddress,_that.destinationLat,_that.destinationLng,_that.meetingUrl,_that.eventKind,_that.calendarSourceId,_that.anchor,_that.sourceType,_that.status,_that.autoManageExcluded);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String eventId,  String? title,  String? displayLabel,  String displayName,  DateTime startsAt,  String? timezone,  DateTime? endsAt,  LocationState locationState,  String? destinationName,  String? destinationAddress,  double? destinationLat,  double? destinationLng,  String? meetingUrl,  String? eventKind,  String? calendarSourceId,  EventAnchor anchor,  EventSourceType sourceType,  EventLifecycleStatus? status,  bool? autoManageExcluded)?  $default,) {final _that = this;
switch (_that) {
case _Event() when $default != null:
return $default(_that.eventId,_that.title,_that.displayLabel,_that.displayName,_that.startsAt,_that.timezone,_that.endsAt,_that.locationState,_that.destinationName,_that.destinationAddress,_that.destinationLat,_that.destinationLng,_that.meetingUrl,_that.eventKind,_that.calendarSourceId,_that.anchor,_that.sourceType,_that.status,_that.autoManageExcluded);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Event implements Event {
  const _Event({required this.eventId, this.title, this.displayLabel, required this.displayName, required this.startsAt, this.timezone, this.endsAt, required this.locationState, this.destinationName, this.destinationAddress, this.destinationLat, this.destinationLng, this.meetingUrl, this.eventKind, this.calendarSourceId, this.anchor = EventAnchor.arriveBy, this.sourceType = EventSourceType.internal, this.status, this.autoManageExcluded});
  factory _Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

@override final  String eventId;
@override final  String? title;
@override final  String? displayLabel;
@override final  String displayName;
@override final  DateTime startsAt;
@override final  String? timezone;
// BE EventResponse.endsAt은 nullable이다 — 종료 시각 없이 만든 일정이
// 그대로 null로 내려온다.
@override final  DateTime? endsAt;
@override final  LocationState locationState;
@override final  String? destinationName;
@override final  String? destinationAddress;
@override final  double? destinationLat;
@override final  double? destinationLng;
@override final  String? meetingUrl;
@override final  String? eventKind;
@override final  String? calendarSourceId;
@override@JsonKey() final  EventAnchor anchor;
@override@JsonKey() final  EventSourceType sourceType;
@override final  EventLifecycleStatus? status;
@override final  bool? autoManageExcluded;

/// Create a copy of Event
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EventCopyWith<_Event> get copyWith => __$EventCopyWithImpl<_Event>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Event&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.title, title) || other.title == title)&&(identical(other.displayLabel, displayLabel) || other.displayLabel == displayLabel)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.locationState, locationState) || other.locationState == locationState)&&(identical(other.destinationName, destinationName) || other.destinationName == destinationName)&&(identical(other.destinationAddress, destinationAddress) || other.destinationAddress == destinationAddress)&&(identical(other.destinationLat, destinationLat) || other.destinationLat == destinationLat)&&(identical(other.destinationLng, destinationLng) || other.destinationLng == destinationLng)&&(identical(other.meetingUrl, meetingUrl) || other.meetingUrl == meetingUrl)&&(identical(other.eventKind, eventKind) || other.eventKind == eventKind)&&(identical(other.calendarSourceId, calendarSourceId) || other.calendarSourceId == calendarSourceId)&&(identical(other.anchor, anchor) || other.anchor == anchor)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.status, status) || other.status == status)&&(identical(other.autoManageExcluded, autoManageExcluded) || other.autoManageExcluded == autoManageExcluded));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,eventId,title,displayLabel,displayName,startsAt,timezone,endsAt,locationState,destinationName,destinationAddress,destinationLat,destinationLng,meetingUrl,eventKind,calendarSourceId,anchor,sourceType,status,autoManageExcluded]);

@override
String toString() {
  return 'Event(eventId: $eventId, title: $title, displayLabel: $displayLabel, displayName: $displayName, startsAt: $startsAt, timezone: $timezone, endsAt: $endsAt, locationState: $locationState, destinationName: $destinationName, destinationAddress: $destinationAddress, destinationLat: $destinationLat, destinationLng: $destinationLng, meetingUrl: $meetingUrl, eventKind: $eventKind, calendarSourceId: $calendarSourceId, anchor: $anchor, sourceType: $sourceType, status: $status, autoManageExcluded: $autoManageExcluded)';
}


}

/// @nodoc
abstract mixin class _$EventCopyWith<$Res> implements $EventCopyWith<$Res> {
  factory _$EventCopyWith(_Event value, $Res Function(_Event) _then) = __$EventCopyWithImpl;
@override @useResult
$Res call({
 String eventId, String? title, String? displayLabel, String displayName, DateTime startsAt, String? timezone, DateTime? endsAt, LocationState locationState, String? destinationName, String? destinationAddress, double? destinationLat, double? destinationLng, String? meetingUrl, String? eventKind, String? calendarSourceId, EventAnchor anchor, EventSourceType sourceType, EventLifecycleStatus? status, bool? autoManageExcluded
});




}
/// @nodoc
class __$EventCopyWithImpl<$Res>
    implements _$EventCopyWith<$Res> {
  __$EventCopyWithImpl(this._self, this._then);

  final _Event _self;
  final $Res Function(_Event) _then;

/// Create a copy of Event
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? title = freezed,Object? displayLabel = freezed,Object? displayName = null,Object? startsAt = null,Object? timezone = freezed,Object? endsAt = freezed,Object? locationState = null,Object? destinationName = freezed,Object? destinationAddress = freezed,Object? destinationLat = freezed,Object? destinationLng = freezed,Object? meetingUrl = freezed,Object? eventKind = freezed,Object? calendarSourceId = freezed,Object? anchor = null,Object? sourceType = null,Object? status = freezed,Object? autoManageExcluded = freezed,}) {
  return _then(_Event(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,displayLabel: freezed == displayLabel ? _self.displayLabel : displayLabel // ignore: cast_nullable_to_non_nullable
as String?,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,timezone: freezed == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String?,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,locationState: null == locationState ? _self.locationState : locationState // ignore: cast_nullable_to_non_nullable
as LocationState,destinationName: freezed == destinationName ? _self.destinationName : destinationName // ignore: cast_nullable_to_non_nullable
as String?,destinationAddress: freezed == destinationAddress ? _self.destinationAddress : destinationAddress // ignore: cast_nullable_to_non_nullable
as String?,destinationLat: freezed == destinationLat ? _self.destinationLat : destinationLat // ignore: cast_nullable_to_non_nullable
as double?,destinationLng: freezed == destinationLng ? _self.destinationLng : destinationLng // ignore: cast_nullable_to_non_nullable
as double?,meetingUrl: freezed == meetingUrl ? _self.meetingUrl : meetingUrl // ignore: cast_nullable_to_non_nullable
as String?,eventKind: freezed == eventKind ? _self.eventKind : eventKind // ignore: cast_nullable_to_non_nullable
as String?,calendarSourceId: freezed == calendarSourceId ? _self.calendarSourceId : calendarSourceId // ignore: cast_nullable_to_non_nullable
as String?,anchor: null == anchor ? _self.anchor : anchor // ignore: cast_nullable_to_non_nullable
as EventAnchor,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as EventSourceType,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EventLifecycleStatus?,autoManageExcluded: freezed == autoManageExcluded ? _self.autoManageExcluded : autoManageExcluded // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$EventClassificationReview {

 String get questionType; String get userAnswer;
/// Create a copy of EventClassificationReview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EventClassificationReviewCopyWith<EventClassificationReview> get copyWith => _$EventClassificationReviewCopyWithImpl<EventClassificationReview>(this as EventClassificationReview, _$identity);

  /// Serializes this EventClassificationReview to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EventClassificationReview&&(identical(other.questionType, questionType) || other.questionType == questionType)&&(identical(other.userAnswer, userAnswer) || other.userAnswer == userAnswer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,questionType,userAnswer);

@override
String toString() {
  return 'EventClassificationReview(questionType: $questionType, userAnswer: $userAnswer)';
}


}

/// @nodoc
abstract mixin class $EventClassificationReviewCopyWith<$Res>  {
  factory $EventClassificationReviewCopyWith(EventClassificationReview value, $Res Function(EventClassificationReview) _then) = _$EventClassificationReviewCopyWithImpl;
@useResult
$Res call({
 String questionType, String userAnswer
});




}
/// @nodoc
class _$EventClassificationReviewCopyWithImpl<$Res>
    implements $EventClassificationReviewCopyWith<$Res> {
  _$EventClassificationReviewCopyWithImpl(this._self, this._then);

  final EventClassificationReview _self;
  final $Res Function(EventClassificationReview) _then;

/// Create a copy of EventClassificationReview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? questionType = null,Object? userAnswer = null,}) {
  return _then(_self.copyWith(
questionType: null == questionType ? _self.questionType : questionType // ignore: cast_nullable_to_non_nullable
as String,userAnswer: null == userAnswer ? _self.userAnswer : userAnswer // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [EventClassificationReview].
extension EventClassificationReviewPatterns on EventClassificationReview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EventClassificationReview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EventClassificationReview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EventClassificationReview value)  $default,){
final _that = this;
switch (_that) {
case _EventClassificationReview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EventClassificationReview value)?  $default,){
final _that = this;
switch (_that) {
case _EventClassificationReview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String questionType,  String userAnswer)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EventClassificationReview() when $default != null:
return $default(_that.questionType,_that.userAnswer);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String questionType,  String userAnswer)  $default,) {final _that = this;
switch (_that) {
case _EventClassificationReview():
return $default(_that.questionType,_that.userAnswer);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String questionType,  String userAnswer)?  $default,) {final _that = this;
switch (_that) {
case _EventClassificationReview() when $default != null:
return $default(_that.questionType,_that.userAnswer);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EventClassificationReview implements EventClassificationReview {
  const _EventClassificationReview({required this.questionType, required this.userAnswer});
  factory _EventClassificationReview.fromJson(Map<String, dynamic> json) => _$EventClassificationReviewFromJson(json);

@override final  String questionType;
@override final  String userAnswer;

/// Create a copy of EventClassificationReview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EventClassificationReviewCopyWith<_EventClassificationReview> get copyWith => __$EventClassificationReviewCopyWithImpl<_EventClassificationReview>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EventClassificationReviewToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EventClassificationReview&&(identical(other.questionType, questionType) || other.questionType == questionType)&&(identical(other.userAnswer, userAnswer) || other.userAnswer == userAnswer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,questionType,userAnswer);

@override
String toString() {
  return 'EventClassificationReview(questionType: $questionType, userAnswer: $userAnswer)';
}


}

/// @nodoc
abstract mixin class _$EventClassificationReviewCopyWith<$Res> implements $EventClassificationReviewCopyWith<$Res> {
  factory _$EventClassificationReviewCopyWith(_EventClassificationReview value, $Res Function(_EventClassificationReview) _then) = __$EventClassificationReviewCopyWithImpl;
@override @useResult
$Res call({
 String questionType, String userAnswer
});




}
/// @nodoc
class __$EventClassificationReviewCopyWithImpl<$Res>
    implements _$EventClassificationReviewCopyWith<$Res> {
  __$EventClassificationReviewCopyWithImpl(this._self, this._then);

  final _EventClassificationReview _self;
  final $Res Function(_EventClassificationReview) _then;

/// Create a copy of EventClassificationReview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? questionType = null,Object? userAnswer = null,}) {
  return _then(_EventClassificationReview(
questionType: null == questionType ? _self.questionType : questionType // ignore: cast_nullable_to_non_nullable
as String,userAnswer: null == userAnswer ? _self.userAnswer : userAnswer // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
