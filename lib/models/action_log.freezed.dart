// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'action_log.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ActionLogEntry {

 String get clientEventId; ActionType get actionType;// 기기 시각(deviceTs)은 UTC(Z)로 직렬화한다. 로컬 DateTime의
// toIso8601String()은 오프셋/Z가 없어 BE(Instant) 파싱이 400으로
// 실패한다. updatePlan/reportArrival과 동일한 toUtc() 규약.
@JsonKey(toJson: iso8601WithOffset) DateTime get deviceTs; ActionSource get actionSource; double? get confidence;
/// Create a copy of ActionLogEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActionLogEntryCopyWith<ActionLogEntry> get copyWith => _$ActionLogEntryCopyWithImpl<ActionLogEntry>(this as ActionLogEntry, _$identity);

  /// Serializes this ActionLogEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActionLogEntry&&(identical(other.clientEventId, clientEventId) || other.clientEventId == clientEventId)&&(identical(other.actionType, actionType) || other.actionType == actionType)&&(identical(other.deviceTs, deviceTs) || other.deviceTs == deviceTs)&&(identical(other.actionSource, actionSource) || other.actionSource == actionSource)&&(identical(other.confidence, confidence) || other.confidence == confidence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,clientEventId,actionType,deviceTs,actionSource,confidence);

@override
String toString() {
  return 'ActionLogEntry(clientEventId: $clientEventId, actionType: $actionType, deviceTs: $deviceTs, actionSource: $actionSource, confidence: $confidence)';
}


}

/// @nodoc
abstract mixin class $ActionLogEntryCopyWith<$Res>  {
  factory $ActionLogEntryCopyWith(ActionLogEntry value, $Res Function(ActionLogEntry) _then) = _$ActionLogEntryCopyWithImpl;
@useResult
$Res call({
 String clientEventId, ActionType actionType,@JsonKey(toJson: iso8601WithOffset) DateTime deviceTs, ActionSource actionSource, double? confidence
});




}
/// @nodoc
class _$ActionLogEntryCopyWithImpl<$Res>
    implements $ActionLogEntryCopyWith<$Res> {
  _$ActionLogEntryCopyWithImpl(this._self, this._then);

  final ActionLogEntry _self;
  final $Res Function(ActionLogEntry) _then;

/// Create a copy of ActionLogEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? clientEventId = null,Object? actionType = null,Object? deviceTs = null,Object? actionSource = null,Object? confidence = freezed,}) {
  return _then(_self.copyWith(
clientEventId: null == clientEventId ? _self.clientEventId : clientEventId // ignore: cast_nullable_to_non_nullable
as String,actionType: null == actionType ? _self.actionType : actionType // ignore: cast_nullable_to_non_nullable
as ActionType,deviceTs: null == deviceTs ? _self.deviceTs : deviceTs // ignore: cast_nullable_to_non_nullable
as DateTime,actionSource: null == actionSource ? _self.actionSource : actionSource // ignore: cast_nullable_to_non_nullable
as ActionSource,confidence: freezed == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [ActionLogEntry].
extension ActionLogEntryPatterns on ActionLogEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActionLogEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActionLogEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActionLogEntry value)  $default,){
final _that = this;
switch (_that) {
case _ActionLogEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActionLogEntry value)?  $default,){
final _that = this;
switch (_that) {
case _ActionLogEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String clientEventId,  ActionType actionType, @JsonKey(toJson: iso8601WithOffset)  DateTime deviceTs,  ActionSource actionSource,  double? confidence)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActionLogEntry() when $default != null:
return $default(_that.clientEventId,_that.actionType,_that.deviceTs,_that.actionSource,_that.confidence);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String clientEventId,  ActionType actionType, @JsonKey(toJson: iso8601WithOffset)  DateTime deviceTs,  ActionSource actionSource,  double? confidence)  $default,) {final _that = this;
switch (_that) {
case _ActionLogEntry():
return $default(_that.clientEventId,_that.actionType,_that.deviceTs,_that.actionSource,_that.confidence);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String clientEventId,  ActionType actionType, @JsonKey(toJson: iso8601WithOffset)  DateTime deviceTs,  ActionSource actionSource,  double? confidence)?  $default,) {final _that = this;
switch (_that) {
case _ActionLogEntry() when $default != null:
return $default(_that.clientEventId,_that.actionType,_that.deviceTs,_that.actionSource,_that.confidence);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActionLogEntry implements ActionLogEntry {
  const _ActionLogEntry({required this.clientEventId, required this.actionType, @JsonKey(toJson: iso8601WithOffset) required this.deviceTs, required this.actionSource, this.confidence});
  factory _ActionLogEntry.fromJson(Map<String, dynamic> json) => _$ActionLogEntryFromJson(json);

@override final  String clientEventId;
@override final  ActionType actionType;
// 기기 시각(deviceTs)은 UTC(Z)로 직렬화한다. 로컬 DateTime의
// toIso8601String()은 오프셋/Z가 없어 BE(Instant) 파싱이 400으로
// 실패한다. updatePlan/reportArrival과 동일한 toUtc() 규약.
@override@JsonKey(toJson: iso8601WithOffset) final  DateTime deviceTs;
@override final  ActionSource actionSource;
@override final  double? confidence;

/// Create a copy of ActionLogEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActionLogEntryCopyWith<_ActionLogEntry> get copyWith => __$ActionLogEntryCopyWithImpl<_ActionLogEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActionLogEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActionLogEntry&&(identical(other.clientEventId, clientEventId) || other.clientEventId == clientEventId)&&(identical(other.actionType, actionType) || other.actionType == actionType)&&(identical(other.deviceTs, deviceTs) || other.deviceTs == deviceTs)&&(identical(other.actionSource, actionSource) || other.actionSource == actionSource)&&(identical(other.confidence, confidence) || other.confidence == confidence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,clientEventId,actionType,deviceTs,actionSource,confidence);

@override
String toString() {
  return 'ActionLogEntry(clientEventId: $clientEventId, actionType: $actionType, deviceTs: $deviceTs, actionSource: $actionSource, confidence: $confidence)';
}


}

/// @nodoc
abstract mixin class _$ActionLogEntryCopyWith<$Res> implements $ActionLogEntryCopyWith<$Res> {
  factory _$ActionLogEntryCopyWith(_ActionLogEntry value, $Res Function(_ActionLogEntry) _then) = __$ActionLogEntryCopyWithImpl;
@override @useResult
$Res call({
 String clientEventId, ActionType actionType,@JsonKey(toJson: iso8601WithOffset) DateTime deviceTs, ActionSource actionSource, double? confidence
});




}
/// @nodoc
class __$ActionLogEntryCopyWithImpl<$Res>
    implements _$ActionLogEntryCopyWith<$Res> {
  __$ActionLogEntryCopyWithImpl(this._self, this._then);

  final _ActionLogEntry _self;
  final $Res Function(_ActionLogEntry) _then;

/// Create a copy of ActionLogEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? clientEventId = null,Object? actionType = null,Object? deviceTs = null,Object? actionSource = null,Object? confidence = freezed,}) {
  return _then(_ActionLogEntry(
clientEventId: null == clientEventId ? _self.clientEventId : clientEventId // ignore: cast_nullable_to_non_nullable
as String,actionType: null == actionType ? _self.actionType : actionType // ignore: cast_nullable_to_non_nullable
as ActionType,deviceTs: null == deviceTs ? _self.deviceTs : deviceTs // ignore: cast_nullable_to_non_nullable
as DateTime,actionSource: null == actionSource ? _self.actionSource : actionSource // ignore: cast_nullable_to_non_nullable
as ActionSource,confidence: freezed == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$ActionBatchResponse {

 int get accepted; int get duplicated; EventLifecycleStatus get eventStatus; Map<String, dynamic> get plan;
/// Create a copy of ActionBatchResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActionBatchResponseCopyWith<ActionBatchResponse> get copyWith => _$ActionBatchResponseCopyWithImpl<ActionBatchResponse>(this as ActionBatchResponse, _$identity);

  /// Serializes this ActionBatchResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActionBatchResponse&&(identical(other.accepted, accepted) || other.accepted == accepted)&&(identical(other.duplicated, duplicated) || other.duplicated == duplicated)&&(identical(other.eventStatus, eventStatus) || other.eventStatus == eventStatus)&&const DeepCollectionEquality().equals(other.plan, plan));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accepted,duplicated,eventStatus,const DeepCollectionEquality().hash(plan));

@override
String toString() {
  return 'ActionBatchResponse(accepted: $accepted, duplicated: $duplicated, eventStatus: $eventStatus, plan: $plan)';
}


}

/// @nodoc
abstract mixin class $ActionBatchResponseCopyWith<$Res>  {
  factory $ActionBatchResponseCopyWith(ActionBatchResponse value, $Res Function(ActionBatchResponse) _then) = _$ActionBatchResponseCopyWithImpl;
@useResult
$Res call({
 int accepted, int duplicated, EventLifecycleStatus eventStatus, Map<String, dynamic> plan
});




}
/// @nodoc
class _$ActionBatchResponseCopyWithImpl<$Res>
    implements $ActionBatchResponseCopyWith<$Res> {
  _$ActionBatchResponseCopyWithImpl(this._self, this._then);

  final ActionBatchResponse _self;
  final $Res Function(ActionBatchResponse) _then;

/// Create a copy of ActionBatchResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accepted = null,Object? duplicated = null,Object? eventStatus = null,Object? plan = null,}) {
  return _then(_self.copyWith(
accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as int,duplicated: null == duplicated ? _self.duplicated : duplicated // ignore: cast_nullable_to_non_nullable
as int,eventStatus: null == eventStatus ? _self.eventStatus : eventStatus // ignore: cast_nullable_to_non_nullable
as EventLifecycleStatus,plan: null == plan ? _self.plan : plan // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [ActionBatchResponse].
extension ActionBatchResponsePatterns on ActionBatchResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActionBatchResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActionBatchResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActionBatchResponse value)  $default,){
final _that = this;
switch (_that) {
case _ActionBatchResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActionBatchResponse value)?  $default,){
final _that = this;
switch (_that) {
case _ActionBatchResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int accepted,  int duplicated,  EventLifecycleStatus eventStatus,  Map<String, dynamic> plan)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActionBatchResponse() when $default != null:
return $default(_that.accepted,_that.duplicated,_that.eventStatus,_that.plan);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int accepted,  int duplicated,  EventLifecycleStatus eventStatus,  Map<String, dynamic> plan)  $default,) {final _that = this;
switch (_that) {
case _ActionBatchResponse():
return $default(_that.accepted,_that.duplicated,_that.eventStatus,_that.plan);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int accepted,  int duplicated,  EventLifecycleStatus eventStatus,  Map<String, dynamic> plan)?  $default,) {final _that = this;
switch (_that) {
case _ActionBatchResponse() when $default != null:
return $default(_that.accepted,_that.duplicated,_that.eventStatus,_that.plan);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActionBatchResponse implements ActionBatchResponse {
  const _ActionBatchResponse({required this.accepted, required this.duplicated, required this.eventStatus, required final  Map<String, dynamic> plan}): _plan = plan;
  factory _ActionBatchResponse.fromJson(Map<String, dynamic> json) => _$ActionBatchResponseFromJson(json);

@override final  int accepted;
@override final  int duplicated;
@override final  EventLifecycleStatus eventStatus;
 final  Map<String, dynamic> _plan;
@override Map<String, dynamic> get plan {
  if (_plan is EqualUnmodifiableMapView) return _plan;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_plan);
}


/// Create a copy of ActionBatchResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActionBatchResponseCopyWith<_ActionBatchResponse> get copyWith => __$ActionBatchResponseCopyWithImpl<_ActionBatchResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActionBatchResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActionBatchResponse&&(identical(other.accepted, accepted) || other.accepted == accepted)&&(identical(other.duplicated, duplicated) || other.duplicated == duplicated)&&(identical(other.eventStatus, eventStatus) || other.eventStatus == eventStatus)&&const DeepCollectionEquality().equals(other._plan, _plan));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accepted,duplicated,eventStatus,const DeepCollectionEquality().hash(_plan));

@override
String toString() {
  return 'ActionBatchResponse(accepted: $accepted, duplicated: $duplicated, eventStatus: $eventStatus, plan: $plan)';
}


}

/// @nodoc
abstract mixin class _$ActionBatchResponseCopyWith<$Res> implements $ActionBatchResponseCopyWith<$Res> {
  factory _$ActionBatchResponseCopyWith(_ActionBatchResponse value, $Res Function(_ActionBatchResponse) _then) = __$ActionBatchResponseCopyWithImpl;
@override @useResult
$Res call({
 int accepted, int duplicated, EventLifecycleStatus eventStatus, Map<String, dynamic> plan
});




}
/// @nodoc
class __$ActionBatchResponseCopyWithImpl<$Res>
    implements _$ActionBatchResponseCopyWith<$Res> {
  __$ActionBatchResponseCopyWithImpl(this._self, this._then);

  final _ActionBatchResponse _self;
  final $Res Function(_ActionBatchResponse) _then;

/// Create a copy of ActionBatchResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accepted = null,Object? duplicated = null,Object? eventStatus = null,Object? plan = null,}) {
  return _then(_ActionBatchResponse(
accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as int,duplicated: null == duplicated ? _self.duplicated : duplicated // ignore: cast_nullable_to_non_nullable
as int,eventStatus: null == eventStatus ? _self.eventStatus : eventStatus // ignore: cast_nullable_to_non_nullable
as EventLifecycleStatus,plan: null == plan ? _self._plan : plan // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
