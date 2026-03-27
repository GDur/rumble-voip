// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'client.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AudioEvent {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioEvent&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'AudioEvent(field0: $field0)';
}


}

/// @nodoc
class $AudioEventCopyWith<$Res>  {
$AudioEventCopyWith(AudioEvent _, $Res Function(AudioEvent) __);
}


/// Adds pattern-matching-related methods to [AudioEvent].
extension AudioEventPatterns on AudioEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AudioEvent_AudioVolume value)?  audioVolume,TResult Function( AudioEvent_UserTalking value)?  userTalking,TResult Function( AudioEvent_Disconnected value)?  disconnected,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AudioEvent_AudioVolume() when audioVolume != null:
return audioVolume(_that);case AudioEvent_UserTalking() when userTalking != null:
return userTalking(_that);case AudioEvent_Disconnected() when disconnected != null:
return disconnected(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AudioEvent_AudioVolume value)  audioVolume,required TResult Function( AudioEvent_UserTalking value)  userTalking,required TResult Function( AudioEvent_Disconnected value)  disconnected,}){
final _that = this;
switch (_that) {
case AudioEvent_AudioVolume():
return audioVolume(_that);case AudioEvent_UserTalking():
return userTalking(_that);case AudioEvent_Disconnected():
return disconnected(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AudioEvent_AudioVolume value)?  audioVolume,TResult? Function( AudioEvent_UserTalking value)?  userTalking,TResult? Function( AudioEvent_Disconnected value)?  disconnected,}){
final _that = this;
switch (_that) {
case AudioEvent_AudioVolume() when audioVolume != null:
return audioVolume(_that);case AudioEvent_UserTalking() when userTalking != null:
return userTalking(_that);case AudioEvent_Disconnected() when disconnected != null:
return disconnected(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( double field0)?  audioVolume,TResult Function( int field0,  bool field1)?  userTalking,TResult Function( String field0)?  disconnected,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AudioEvent_AudioVolume() when audioVolume != null:
return audioVolume(_that.field0);case AudioEvent_UserTalking() when userTalking != null:
return userTalking(_that.field0,_that.field1);case AudioEvent_Disconnected() when disconnected != null:
return disconnected(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( double field0)  audioVolume,required TResult Function( int field0,  bool field1)  userTalking,required TResult Function( String field0)  disconnected,}) {final _that = this;
switch (_that) {
case AudioEvent_AudioVolume():
return audioVolume(_that.field0);case AudioEvent_UserTalking():
return userTalking(_that.field0,_that.field1);case AudioEvent_Disconnected():
return disconnected(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( double field0)?  audioVolume,TResult? Function( int field0,  bool field1)?  userTalking,TResult? Function( String field0)?  disconnected,}) {final _that = this;
switch (_that) {
case AudioEvent_AudioVolume() when audioVolume != null:
return audioVolume(_that.field0);case AudioEvent_UserTalking() when userTalking != null:
return userTalking(_that.field0,_that.field1);case AudioEvent_Disconnected() when disconnected != null:
return disconnected(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class AudioEvent_AudioVolume extends AudioEvent {
  const AudioEvent_AudioVolume(this.field0): super._();
  

@override final  double field0;

/// Create a copy of AudioEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioEvent_AudioVolumeCopyWith<AudioEvent_AudioVolume> get copyWith => _$AudioEvent_AudioVolumeCopyWithImpl<AudioEvent_AudioVolume>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioEvent_AudioVolume&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'AudioEvent.audioVolume(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $AudioEvent_AudioVolumeCopyWith<$Res> implements $AudioEventCopyWith<$Res> {
  factory $AudioEvent_AudioVolumeCopyWith(AudioEvent_AudioVolume value, $Res Function(AudioEvent_AudioVolume) _then) = _$AudioEvent_AudioVolumeCopyWithImpl;
@useResult
$Res call({
 double field0
});




}
/// @nodoc
class _$AudioEvent_AudioVolumeCopyWithImpl<$Res>
    implements $AudioEvent_AudioVolumeCopyWith<$Res> {
  _$AudioEvent_AudioVolumeCopyWithImpl(this._self, this._then);

  final AudioEvent_AudioVolume _self;
  final $Res Function(AudioEvent_AudioVolume) _then;

/// Create a copy of AudioEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(AudioEvent_AudioVolume(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class AudioEvent_UserTalking extends AudioEvent {
  const AudioEvent_UserTalking(this.field0, this.field1): super._();
  

@override final  int field0;
 final  bool field1;

/// Create a copy of AudioEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioEvent_UserTalkingCopyWith<AudioEvent_UserTalking> get copyWith => _$AudioEvent_UserTalkingCopyWithImpl<AudioEvent_UserTalking>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioEvent_UserTalking&&(identical(other.field0, field0) || other.field0 == field0)&&(identical(other.field1, field1) || other.field1 == field1));
}


@override
int get hashCode => Object.hash(runtimeType,field0,field1);

@override
String toString() {
  return 'AudioEvent.userTalking(field0: $field0, field1: $field1)';
}


}

/// @nodoc
abstract mixin class $AudioEvent_UserTalkingCopyWith<$Res> implements $AudioEventCopyWith<$Res> {
  factory $AudioEvent_UserTalkingCopyWith(AudioEvent_UserTalking value, $Res Function(AudioEvent_UserTalking) _then) = _$AudioEvent_UserTalkingCopyWithImpl;
@useResult
$Res call({
 int field0, bool field1
});




}
/// @nodoc
class _$AudioEvent_UserTalkingCopyWithImpl<$Res>
    implements $AudioEvent_UserTalkingCopyWith<$Res> {
  _$AudioEvent_UserTalkingCopyWithImpl(this._self, this._then);

  final AudioEvent_UserTalking _self;
  final $Res Function(AudioEvent_UserTalking) _then;

/// Create a copy of AudioEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,Object? field1 = null,}) {
  return _then(AudioEvent_UserTalking(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,null == field1 ? _self.field1 : field1 // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class AudioEvent_Disconnected extends AudioEvent {
  const AudioEvent_Disconnected(this.field0): super._();
  

@override final  String field0;

/// Create a copy of AudioEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioEvent_DisconnectedCopyWith<AudioEvent_Disconnected> get copyWith => _$AudioEvent_DisconnectedCopyWithImpl<AudioEvent_Disconnected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioEvent_Disconnected&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'AudioEvent.disconnected(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $AudioEvent_DisconnectedCopyWith<$Res> implements $AudioEventCopyWith<$Res> {
  factory $AudioEvent_DisconnectedCopyWith(AudioEvent_Disconnected value, $Res Function(AudioEvent_Disconnected) _then) = _$AudioEvent_DisconnectedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$AudioEvent_DisconnectedCopyWithImpl<$Res>
    implements $AudioEvent_DisconnectedCopyWith<$Res> {
  _$AudioEvent_DisconnectedCopyWithImpl(this._self, this._then);

  final AudioEvent_Disconnected _self;
  final $Res Function(AudioEvent_Disconnected) _then;

/// Create a copy of AudioEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(AudioEvent_Disconnected(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
