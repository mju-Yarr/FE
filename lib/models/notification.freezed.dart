// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppNotification {

 String get notificationId; String get planId; NotificationCategory get notificationCategory; NotificationType get notificationType; String get slot;// time: A|B|C, wellness: W
 DateTime? get scheduledAt; DateTime? get sentAt; DeliveryStatus? get deliveryStatus; String get body; String? get triggerReason; String? get reaction;
/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppNotificationCopyWith<AppNotification> get copyWith => _$AppNotificationCopyWithImpl<AppNotification>(this as AppNotification, _$identity);

  /// Serializes this AppNotification to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppNotification&&(identical(other.notificationId, notificationId) || other.notificationId == notificationId)&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.notificationCategory, notificationCategory) || other.notificationCategory == notificationCategory)&&(identical(other.notificationType, notificationType) || other.notificationType == notificationType)&&(identical(other.slot, slot) || other.slot == slot)&&(identical(other.scheduledAt, scheduledAt) || other.scheduledAt == scheduledAt)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.deliveryStatus, deliveryStatus) || other.deliveryStatus == deliveryStatus)&&(identical(other.body, body) || other.body == body)&&(identical(other.triggerReason, triggerReason) || other.triggerReason == triggerReason)&&(identical(other.reaction, reaction) || other.reaction == reaction));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,notificationId,planId,notificationCategory,notificationType,slot,scheduledAt,sentAt,deliveryStatus,body,triggerReason,reaction);

@override
String toString() {
  return 'AppNotification(notificationId: $notificationId, planId: $planId, notificationCategory: $notificationCategory, notificationType: $notificationType, slot: $slot, scheduledAt: $scheduledAt, sentAt: $sentAt, deliveryStatus: $deliveryStatus, body: $body, triggerReason: $triggerReason, reaction: $reaction)';
}


}

/// @nodoc
abstract mixin class $AppNotificationCopyWith<$Res>  {
  factory $AppNotificationCopyWith(AppNotification value, $Res Function(AppNotification) _then) = _$AppNotificationCopyWithImpl;
@useResult
$Res call({
 String notificationId, String planId, NotificationCategory notificationCategory, NotificationType notificationType, String slot, DateTime? scheduledAt, DateTime? sentAt, DeliveryStatus? deliveryStatus, String body, String? triggerReason, String? reaction
});




}
/// @nodoc
class _$AppNotificationCopyWithImpl<$Res>
    implements $AppNotificationCopyWith<$Res> {
  _$AppNotificationCopyWithImpl(this._self, this._then);

  final AppNotification _self;
  final $Res Function(AppNotification) _then;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? notificationId = null,Object? planId = null,Object? notificationCategory = null,Object? notificationType = null,Object? slot = null,Object? scheduledAt = freezed,Object? sentAt = freezed,Object? deliveryStatus = freezed,Object? body = null,Object? triggerReason = freezed,Object? reaction = freezed,}) {
  return _then(_self.copyWith(
notificationId: null == notificationId ? _self.notificationId : notificationId // ignore: cast_nullable_to_non_nullable
as String,planId: null == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String,notificationCategory: null == notificationCategory ? _self.notificationCategory : notificationCategory // ignore: cast_nullable_to_non_nullable
as NotificationCategory,notificationType: null == notificationType ? _self.notificationType : notificationType // ignore: cast_nullable_to_non_nullable
as NotificationType,slot: null == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as String,scheduledAt: freezed == scheduledAt ? _self.scheduledAt : scheduledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deliveryStatus: freezed == deliveryStatus ? _self.deliveryStatus : deliveryStatus // ignore: cast_nullable_to_non_nullable
as DeliveryStatus?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,triggerReason: freezed == triggerReason ? _self.triggerReason : triggerReason // ignore: cast_nullable_to_non_nullable
as String?,reaction: freezed == reaction ? _self.reaction : reaction // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppNotification].
extension AppNotificationPatterns on AppNotification {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppNotification value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppNotification value)  $default,){
final _that = this;
switch (_that) {
case _AppNotification():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppNotification value)?  $default,){
final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String notificationId,  String planId,  NotificationCategory notificationCategory,  NotificationType notificationType,  String slot,  DateTime? scheduledAt,  DateTime? sentAt,  DeliveryStatus? deliveryStatus,  String body,  String? triggerReason,  String? reaction)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
return $default(_that.notificationId,_that.planId,_that.notificationCategory,_that.notificationType,_that.slot,_that.scheduledAt,_that.sentAt,_that.deliveryStatus,_that.body,_that.triggerReason,_that.reaction);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String notificationId,  String planId,  NotificationCategory notificationCategory,  NotificationType notificationType,  String slot,  DateTime? scheduledAt,  DateTime? sentAt,  DeliveryStatus? deliveryStatus,  String body,  String? triggerReason,  String? reaction)  $default,) {final _that = this;
switch (_that) {
case _AppNotification():
return $default(_that.notificationId,_that.planId,_that.notificationCategory,_that.notificationType,_that.slot,_that.scheduledAt,_that.sentAt,_that.deliveryStatus,_that.body,_that.triggerReason,_that.reaction);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String notificationId,  String planId,  NotificationCategory notificationCategory,  NotificationType notificationType,  String slot,  DateTime? scheduledAt,  DateTime? sentAt,  DeliveryStatus? deliveryStatus,  String body,  String? triggerReason,  String? reaction)?  $default,) {final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
return $default(_that.notificationId,_that.planId,_that.notificationCategory,_that.notificationType,_that.slot,_that.scheduledAt,_that.sentAt,_that.deliveryStatus,_that.body,_that.triggerReason,_that.reaction);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppNotification implements AppNotification {
  const _AppNotification({required this.notificationId, required this.planId, required this.notificationCategory, required this.notificationType, required this.slot, this.scheduledAt, this.sentAt, this.deliveryStatus, required this.body, this.triggerReason, this.reaction});
  factory _AppNotification.fromJson(Map<String, dynamic> json) => _$AppNotificationFromJson(json);

@override final  String notificationId;
@override final  String planId;
@override final  NotificationCategory notificationCategory;
@override final  NotificationType notificationType;
@override final  String slot;
// time: A|B|C, wellness: W
@override final  DateTime? scheduledAt;
@override final  DateTime? sentAt;
@override final  DeliveryStatus? deliveryStatus;
@override final  String body;
@override final  String? triggerReason;
@override final  String? reaction;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppNotificationCopyWith<_AppNotification> get copyWith => __$AppNotificationCopyWithImpl<_AppNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppNotification&&(identical(other.notificationId, notificationId) || other.notificationId == notificationId)&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.notificationCategory, notificationCategory) || other.notificationCategory == notificationCategory)&&(identical(other.notificationType, notificationType) || other.notificationType == notificationType)&&(identical(other.slot, slot) || other.slot == slot)&&(identical(other.scheduledAt, scheduledAt) || other.scheduledAt == scheduledAt)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.deliveryStatus, deliveryStatus) || other.deliveryStatus == deliveryStatus)&&(identical(other.body, body) || other.body == body)&&(identical(other.triggerReason, triggerReason) || other.triggerReason == triggerReason)&&(identical(other.reaction, reaction) || other.reaction == reaction));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,notificationId,planId,notificationCategory,notificationType,slot,scheduledAt,sentAt,deliveryStatus,body,triggerReason,reaction);

@override
String toString() {
  return 'AppNotification(notificationId: $notificationId, planId: $planId, notificationCategory: $notificationCategory, notificationType: $notificationType, slot: $slot, scheduledAt: $scheduledAt, sentAt: $sentAt, deliveryStatus: $deliveryStatus, body: $body, triggerReason: $triggerReason, reaction: $reaction)';
}


}

/// @nodoc
abstract mixin class _$AppNotificationCopyWith<$Res> implements $AppNotificationCopyWith<$Res> {
  factory _$AppNotificationCopyWith(_AppNotification value, $Res Function(_AppNotification) _then) = __$AppNotificationCopyWithImpl;
@override @useResult
$Res call({
 String notificationId, String planId, NotificationCategory notificationCategory, NotificationType notificationType, String slot, DateTime? scheduledAt, DateTime? sentAt, DeliveryStatus? deliveryStatus, String body, String? triggerReason, String? reaction
});




}
/// @nodoc
class __$AppNotificationCopyWithImpl<$Res>
    implements _$AppNotificationCopyWith<$Res> {
  __$AppNotificationCopyWithImpl(this._self, this._then);

  final _AppNotification _self;
  final $Res Function(_AppNotification) _then;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? notificationId = null,Object? planId = null,Object? notificationCategory = null,Object? notificationType = null,Object? slot = null,Object? scheduledAt = freezed,Object? sentAt = freezed,Object? deliveryStatus = freezed,Object? body = null,Object? triggerReason = freezed,Object? reaction = freezed,}) {
  return _then(_AppNotification(
notificationId: null == notificationId ? _self.notificationId : notificationId // ignore: cast_nullable_to_non_nullable
as String,planId: null == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String,notificationCategory: null == notificationCategory ? _self.notificationCategory : notificationCategory // ignore: cast_nullable_to_non_nullable
as NotificationCategory,notificationType: null == notificationType ? _self.notificationType : notificationType // ignore: cast_nullable_to_non_nullable
as NotificationType,slot: null == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as String,scheduledAt: freezed == scheduledAt ? _self.scheduledAt : scheduledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deliveryStatus: freezed == deliveryStatus ? _self.deliveryStatus : deliveryStatus // ignore: cast_nullable_to_non_nullable
as DeliveryStatus?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,triggerReason: freezed == triggerReason ? _self.triggerReason : triggerReason // ignore: cast_nullable_to_non_nullable
as String?,reaction: freezed == reaction ? _self.reaction : reaction // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
