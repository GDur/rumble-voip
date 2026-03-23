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
mixin _$MumbleEvent {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MumbleEvent&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'MumbleEvent(field0: $field0)';
}


}

/// @nodoc
class $MumbleEventCopyWith<$Res>  {
$MumbleEventCopyWith(MumbleEvent _, $Res Function(MumbleEvent) __);
}


/// Adds pattern-matching-related methods to [MumbleEvent].
extension MumbleEventPatterns on MumbleEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( MumbleEvent_Connected value)?  connected,TResult Function( MumbleEvent_Disconnected value)?  disconnected,TResult Function( MumbleEvent_ChannelUpdate value)?  channelUpdate,TResult Function( MumbleEvent_UserUpdate value)?  userUpdate,TResult Function( MumbleEvent_UserRemoved value)?  userRemoved,TResult Function( MumbleEvent_UserTalking value)?  userTalking,TResult Function( MumbleEvent_TextMessage value)?  textMessage,TResult Function( MumbleEvent_AudioVolume value)?  audioVolume,required TResult orElse(),}){
final _that = this;
switch (_that) {
case MumbleEvent_Connected() when connected != null:
return connected(_that);case MumbleEvent_Disconnected() when disconnected != null:
return disconnected(_that);case MumbleEvent_ChannelUpdate() when channelUpdate != null:
return channelUpdate(_that);case MumbleEvent_UserUpdate() when userUpdate != null:
return userUpdate(_that);case MumbleEvent_UserRemoved() when userRemoved != null:
return userRemoved(_that);case MumbleEvent_UserTalking() when userTalking != null:
return userTalking(_that);case MumbleEvent_TextMessage() when textMessage != null:
return textMessage(_that);case MumbleEvent_AudioVolume() when audioVolume != null:
return audioVolume(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( MumbleEvent_Connected value)  connected,required TResult Function( MumbleEvent_Disconnected value)  disconnected,required TResult Function( MumbleEvent_ChannelUpdate value)  channelUpdate,required TResult Function( MumbleEvent_UserUpdate value)  userUpdate,required TResult Function( MumbleEvent_UserRemoved value)  userRemoved,required TResult Function( MumbleEvent_UserTalking value)  userTalking,required TResult Function( MumbleEvent_TextMessage value)  textMessage,required TResult Function( MumbleEvent_AudioVolume value)  audioVolume,}){
final _that = this;
switch (_that) {
case MumbleEvent_Connected():
return connected(_that);case MumbleEvent_Disconnected():
return disconnected(_that);case MumbleEvent_ChannelUpdate():
return channelUpdate(_that);case MumbleEvent_UserUpdate():
return userUpdate(_that);case MumbleEvent_UserRemoved():
return userRemoved(_that);case MumbleEvent_UserTalking():
return userTalking(_that);case MumbleEvent_TextMessage():
return textMessage(_that);case MumbleEvent_AudioVolume():
return audioVolume(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( MumbleEvent_Connected value)?  connected,TResult? Function( MumbleEvent_Disconnected value)?  disconnected,TResult? Function( MumbleEvent_ChannelUpdate value)?  channelUpdate,TResult? Function( MumbleEvent_UserUpdate value)?  userUpdate,TResult? Function( MumbleEvent_UserRemoved value)?  userRemoved,TResult? Function( MumbleEvent_UserTalking value)?  userTalking,TResult? Function( MumbleEvent_TextMessage value)?  textMessage,TResult? Function( MumbleEvent_AudioVolume value)?  audioVolume,}){
final _that = this;
switch (_that) {
case MumbleEvent_Connected() when connected != null:
return connected(_that);case MumbleEvent_Disconnected() when disconnected != null:
return disconnected(_that);case MumbleEvent_ChannelUpdate() when channelUpdate != null:
return channelUpdate(_that);case MumbleEvent_UserUpdate() when userUpdate != null:
return userUpdate(_that);case MumbleEvent_UserRemoved() when userRemoved != null:
return userRemoved(_that);case MumbleEvent_UserTalking() when userTalking != null:
return userTalking(_that);case MumbleEvent_TextMessage() when textMessage != null:
return textMessage(_that);case MumbleEvent_AudioVolume() when audioVolume != null:
return audioVolume(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int field0)?  connected,TResult Function( String field0)?  disconnected,TResult Function( MumbleChannel field0)?  channelUpdate,TResult Function( MumbleUser field0)?  userUpdate,TResult Function( int field0)?  userRemoved,TResult Function( int field0,  bool field1)?  userTalking,TResult Function( MumbleTextMessage field0)?  textMessage,TResult Function( double field0)?  audioVolume,required TResult orElse(),}) {final _that = this;
switch (_that) {
case MumbleEvent_Connected() when connected != null:
return connected(_that.field0);case MumbleEvent_Disconnected() when disconnected != null:
return disconnected(_that.field0);case MumbleEvent_ChannelUpdate() when channelUpdate != null:
return channelUpdate(_that.field0);case MumbleEvent_UserUpdate() when userUpdate != null:
return userUpdate(_that.field0);case MumbleEvent_UserRemoved() when userRemoved != null:
return userRemoved(_that.field0);case MumbleEvent_UserTalking() when userTalking != null:
return userTalking(_that.field0,_that.field1);case MumbleEvent_TextMessage() when textMessage != null:
return textMessage(_that.field0);case MumbleEvent_AudioVolume() when audioVolume != null:
return audioVolume(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int field0)  connected,required TResult Function( String field0)  disconnected,required TResult Function( MumbleChannel field0)  channelUpdate,required TResult Function( MumbleUser field0)  userUpdate,required TResult Function( int field0)  userRemoved,required TResult Function( int field0,  bool field1)  userTalking,required TResult Function( MumbleTextMessage field0)  textMessage,required TResult Function( double field0)  audioVolume,}) {final _that = this;
switch (_that) {
case MumbleEvent_Connected():
return connected(_that.field0);case MumbleEvent_Disconnected():
return disconnected(_that.field0);case MumbleEvent_ChannelUpdate():
return channelUpdate(_that.field0);case MumbleEvent_UserUpdate():
return userUpdate(_that.field0);case MumbleEvent_UserRemoved():
return userRemoved(_that.field0);case MumbleEvent_UserTalking():
return userTalking(_that.field0,_that.field1);case MumbleEvent_TextMessage():
return textMessage(_that.field0);case MumbleEvent_AudioVolume():
return audioVolume(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int field0)?  connected,TResult? Function( String field0)?  disconnected,TResult? Function( MumbleChannel field0)?  channelUpdate,TResult? Function( MumbleUser field0)?  userUpdate,TResult? Function( int field0)?  userRemoved,TResult? Function( int field0,  bool field1)?  userTalking,TResult? Function( MumbleTextMessage field0)?  textMessage,TResult? Function( double field0)?  audioVolume,}) {final _that = this;
switch (_that) {
case MumbleEvent_Connected() when connected != null:
return connected(_that.field0);case MumbleEvent_Disconnected() when disconnected != null:
return disconnected(_that.field0);case MumbleEvent_ChannelUpdate() when channelUpdate != null:
return channelUpdate(_that.field0);case MumbleEvent_UserUpdate() when userUpdate != null:
return userUpdate(_that.field0);case MumbleEvent_UserRemoved() when userRemoved != null:
return userRemoved(_that.field0);case MumbleEvent_UserTalking() when userTalking != null:
return userTalking(_that.field0,_that.field1);case MumbleEvent_TextMessage() when textMessage != null:
return textMessage(_that.field0);case MumbleEvent_AudioVolume() when audioVolume != null:
return audioVolume(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class MumbleEvent_Connected extends MumbleEvent {
  const MumbleEvent_Connected(this.field0): super._();
  

@override final  int field0;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MumbleEvent_ConnectedCopyWith<MumbleEvent_Connected> get copyWith => _$MumbleEvent_ConnectedCopyWithImpl<MumbleEvent_Connected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MumbleEvent_Connected&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'MumbleEvent.connected(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $MumbleEvent_ConnectedCopyWith<$Res> implements $MumbleEventCopyWith<$Res> {
  factory $MumbleEvent_ConnectedCopyWith(MumbleEvent_Connected value, $Res Function(MumbleEvent_Connected) _then) = _$MumbleEvent_ConnectedCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$MumbleEvent_ConnectedCopyWithImpl<$Res>
    implements $MumbleEvent_ConnectedCopyWith<$Res> {
  _$MumbleEvent_ConnectedCopyWithImpl(this._self, this._then);

  final MumbleEvent_Connected _self;
  final $Res Function(MumbleEvent_Connected) _then;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(MumbleEvent_Connected(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class MumbleEvent_Disconnected extends MumbleEvent {
  const MumbleEvent_Disconnected(this.field0): super._();
  

@override final  String field0;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MumbleEvent_DisconnectedCopyWith<MumbleEvent_Disconnected> get copyWith => _$MumbleEvent_DisconnectedCopyWithImpl<MumbleEvent_Disconnected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MumbleEvent_Disconnected&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'MumbleEvent.disconnected(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $MumbleEvent_DisconnectedCopyWith<$Res> implements $MumbleEventCopyWith<$Res> {
  factory $MumbleEvent_DisconnectedCopyWith(MumbleEvent_Disconnected value, $Res Function(MumbleEvent_Disconnected) _then) = _$MumbleEvent_DisconnectedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$MumbleEvent_DisconnectedCopyWithImpl<$Res>
    implements $MumbleEvent_DisconnectedCopyWith<$Res> {
  _$MumbleEvent_DisconnectedCopyWithImpl(this._self, this._then);

  final MumbleEvent_Disconnected _self;
  final $Res Function(MumbleEvent_Disconnected) _then;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(MumbleEvent_Disconnected(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class MumbleEvent_ChannelUpdate extends MumbleEvent {
  const MumbleEvent_ChannelUpdate(this.field0): super._();
  

@override final  MumbleChannel field0;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MumbleEvent_ChannelUpdateCopyWith<MumbleEvent_ChannelUpdate> get copyWith => _$MumbleEvent_ChannelUpdateCopyWithImpl<MumbleEvent_ChannelUpdate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MumbleEvent_ChannelUpdate&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'MumbleEvent.channelUpdate(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $MumbleEvent_ChannelUpdateCopyWith<$Res> implements $MumbleEventCopyWith<$Res> {
  factory $MumbleEvent_ChannelUpdateCopyWith(MumbleEvent_ChannelUpdate value, $Res Function(MumbleEvent_ChannelUpdate) _then) = _$MumbleEvent_ChannelUpdateCopyWithImpl;
@useResult
$Res call({
 MumbleChannel field0
});




}
/// @nodoc
class _$MumbleEvent_ChannelUpdateCopyWithImpl<$Res>
    implements $MumbleEvent_ChannelUpdateCopyWith<$Res> {
  _$MumbleEvent_ChannelUpdateCopyWithImpl(this._self, this._then);

  final MumbleEvent_ChannelUpdate _self;
  final $Res Function(MumbleEvent_ChannelUpdate) _then;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(MumbleEvent_ChannelUpdate(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as MumbleChannel,
  ));
}


}

/// @nodoc


class MumbleEvent_UserUpdate extends MumbleEvent {
  const MumbleEvent_UserUpdate(this.field0): super._();
  

@override final  MumbleUser field0;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MumbleEvent_UserUpdateCopyWith<MumbleEvent_UserUpdate> get copyWith => _$MumbleEvent_UserUpdateCopyWithImpl<MumbleEvent_UserUpdate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MumbleEvent_UserUpdate&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'MumbleEvent.userUpdate(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $MumbleEvent_UserUpdateCopyWith<$Res> implements $MumbleEventCopyWith<$Res> {
  factory $MumbleEvent_UserUpdateCopyWith(MumbleEvent_UserUpdate value, $Res Function(MumbleEvent_UserUpdate) _then) = _$MumbleEvent_UserUpdateCopyWithImpl;
@useResult
$Res call({
 MumbleUser field0
});




}
/// @nodoc
class _$MumbleEvent_UserUpdateCopyWithImpl<$Res>
    implements $MumbleEvent_UserUpdateCopyWith<$Res> {
  _$MumbleEvent_UserUpdateCopyWithImpl(this._self, this._then);

  final MumbleEvent_UserUpdate _self;
  final $Res Function(MumbleEvent_UserUpdate) _then;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(MumbleEvent_UserUpdate(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as MumbleUser,
  ));
}


}

/// @nodoc


class MumbleEvent_UserRemoved extends MumbleEvent {
  const MumbleEvent_UserRemoved(this.field0): super._();
  

@override final  int field0;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MumbleEvent_UserRemovedCopyWith<MumbleEvent_UserRemoved> get copyWith => _$MumbleEvent_UserRemovedCopyWithImpl<MumbleEvent_UserRemoved>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MumbleEvent_UserRemoved&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'MumbleEvent.userRemoved(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $MumbleEvent_UserRemovedCopyWith<$Res> implements $MumbleEventCopyWith<$Res> {
  factory $MumbleEvent_UserRemovedCopyWith(MumbleEvent_UserRemoved value, $Res Function(MumbleEvent_UserRemoved) _then) = _$MumbleEvent_UserRemovedCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$MumbleEvent_UserRemovedCopyWithImpl<$Res>
    implements $MumbleEvent_UserRemovedCopyWith<$Res> {
  _$MumbleEvent_UserRemovedCopyWithImpl(this._self, this._then);

  final MumbleEvent_UserRemoved _self;
  final $Res Function(MumbleEvent_UserRemoved) _then;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(MumbleEvent_UserRemoved(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class MumbleEvent_UserTalking extends MumbleEvent {
  const MumbleEvent_UserTalking(this.field0, this.field1): super._();
  

@override final  int field0;
 final  bool field1;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MumbleEvent_UserTalkingCopyWith<MumbleEvent_UserTalking> get copyWith => _$MumbleEvent_UserTalkingCopyWithImpl<MumbleEvent_UserTalking>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MumbleEvent_UserTalking&&(identical(other.field0, field0) || other.field0 == field0)&&(identical(other.field1, field1) || other.field1 == field1));
}


@override
int get hashCode => Object.hash(runtimeType,field0,field1);

@override
String toString() {
  return 'MumbleEvent.userTalking(field0: $field0, field1: $field1)';
}


}

/// @nodoc
abstract mixin class $MumbleEvent_UserTalkingCopyWith<$Res> implements $MumbleEventCopyWith<$Res> {
  factory $MumbleEvent_UserTalkingCopyWith(MumbleEvent_UserTalking value, $Res Function(MumbleEvent_UserTalking) _then) = _$MumbleEvent_UserTalkingCopyWithImpl;
@useResult
$Res call({
 int field0, bool field1
});




}
/// @nodoc
class _$MumbleEvent_UserTalkingCopyWithImpl<$Res>
    implements $MumbleEvent_UserTalkingCopyWith<$Res> {
  _$MumbleEvent_UserTalkingCopyWithImpl(this._self, this._then);

  final MumbleEvent_UserTalking _self;
  final $Res Function(MumbleEvent_UserTalking) _then;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,Object? field1 = null,}) {
  return _then(MumbleEvent_UserTalking(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,null == field1 ? _self.field1 : field1 // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class MumbleEvent_TextMessage extends MumbleEvent {
  const MumbleEvent_TextMessage(this.field0): super._();
  

@override final  MumbleTextMessage field0;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MumbleEvent_TextMessageCopyWith<MumbleEvent_TextMessage> get copyWith => _$MumbleEvent_TextMessageCopyWithImpl<MumbleEvent_TextMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MumbleEvent_TextMessage&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'MumbleEvent.textMessage(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $MumbleEvent_TextMessageCopyWith<$Res> implements $MumbleEventCopyWith<$Res> {
  factory $MumbleEvent_TextMessageCopyWith(MumbleEvent_TextMessage value, $Res Function(MumbleEvent_TextMessage) _then) = _$MumbleEvent_TextMessageCopyWithImpl;
@useResult
$Res call({
 MumbleTextMessage field0
});




}
/// @nodoc
class _$MumbleEvent_TextMessageCopyWithImpl<$Res>
    implements $MumbleEvent_TextMessageCopyWith<$Res> {
  _$MumbleEvent_TextMessageCopyWithImpl(this._self, this._then);

  final MumbleEvent_TextMessage _self;
  final $Res Function(MumbleEvent_TextMessage) _then;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(MumbleEvent_TextMessage(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as MumbleTextMessage,
  ));
}


}

/// @nodoc


class MumbleEvent_AudioVolume extends MumbleEvent {
  const MumbleEvent_AudioVolume(this.field0): super._();
  

@override final  double field0;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MumbleEvent_AudioVolumeCopyWith<MumbleEvent_AudioVolume> get copyWith => _$MumbleEvent_AudioVolumeCopyWithImpl<MumbleEvent_AudioVolume>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MumbleEvent_AudioVolume&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'MumbleEvent.audioVolume(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $MumbleEvent_AudioVolumeCopyWith<$Res> implements $MumbleEventCopyWith<$Res> {
  factory $MumbleEvent_AudioVolumeCopyWith(MumbleEvent_AudioVolume value, $Res Function(MumbleEvent_AudioVolume) _then) = _$MumbleEvent_AudioVolumeCopyWithImpl;
@useResult
$Res call({
 double field0
});




}
/// @nodoc
class _$MumbleEvent_AudioVolumeCopyWithImpl<$Res>
    implements $MumbleEvent_AudioVolumeCopyWith<$Res> {
  _$MumbleEvent_AudioVolumeCopyWithImpl(this._self, this._then);

  final MumbleEvent_AudioVolume _self;
  final $Res Function(MumbleEvent_AudioVolume) _then;

/// Create a copy of MumbleEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(MumbleEvent_AudioVolume(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
