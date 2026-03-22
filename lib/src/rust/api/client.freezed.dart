// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'client.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MumbleEvent {
  Object get field0 => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int field0) connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(MumbleChannel field0) channelUpdate,
    required TResult Function(MumbleUser field0) userUpdate,
    required TResult Function(int field0) userRemoved,
    required TResult Function(MumbleTextMessage field0) textMessage,
    required TResult Function(double field0) audioVolume,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int field0)? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(MumbleChannel field0)? channelUpdate,
    TResult? Function(MumbleUser field0)? userUpdate,
    TResult? Function(int field0)? userRemoved,
    TResult? Function(MumbleTextMessage field0)? textMessage,
    TResult? Function(double field0)? audioVolume,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int field0)? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(MumbleChannel field0)? channelUpdate,
    TResult Function(MumbleUser field0)? userUpdate,
    TResult Function(int field0)? userRemoved,
    TResult Function(MumbleTextMessage field0)? textMessage,
    TResult Function(double field0)? audioVolume,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MumbleEvent_Connected value) connected,
    required TResult Function(MumbleEvent_Disconnected value) disconnected,
    required TResult Function(MumbleEvent_ChannelUpdate value) channelUpdate,
    required TResult Function(MumbleEvent_UserUpdate value) userUpdate,
    required TResult Function(MumbleEvent_UserRemoved value) userRemoved,
    required TResult Function(MumbleEvent_TextMessage value) textMessage,
    required TResult Function(MumbleEvent_AudioVolume value) audioVolume,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MumbleEvent_Connected value)? connected,
    TResult? Function(MumbleEvent_Disconnected value)? disconnected,
    TResult? Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult? Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult? Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult? Function(MumbleEvent_TextMessage value)? textMessage,
    TResult? Function(MumbleEvent_AudioVolume value)? audioVolume,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MumbleEvent_Connected value)? connected,
    TResult Function(MumbleEvent_Disconnected value)? disconnected,
    TResult Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult Function(MumbleEvent_TextMessage value)? textMessage,
    TResult Function(MumbleEvent_AudioVolume value)? audioVolume,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MumbleEventCopyWith<$Res> {
  factory $MumbleEventCopyWith(
    MumbleEvent value,
    $Res Function(MumbleEvent) then,
  ) = _$MumbleEventCopyWithImpl<$Res, MumbleEvent>;
}

/// @nodoc
class _$MumbleEventCopyWithImpl<$Res, $Val extends MumbleEvent>
    implements $MumbleEventCopyWith<$Res> {
  _$MumbleEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$MumbleEvent_ConnectedImplCopyWith<$Res> {
  factory _$$MumbleEvent_ConnectedImplCopyWith(
    _$MumbleEvent_ConnectedImpl value,
    $Res Function(_$MumbleEvent_ConnectedImpl) then,
  ) = __$$MumbleEvent_ConnectedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int field0});
}

/// @nodoc
class __$$MumbleEvent_ConnectedImplCopyWithImpl<$Res>
    extends _$MumbleEventCopyWithImpl<$Res, _$MumbleEvent_ConnectedImpl>
    implements _$$MumbleEvent_ConnectedImplCopyWith<$Res> {
  __$$MumbleEvent_ConnectedImplCopyWithImpl(
    _$MumbleEvent_ConnectedImpl _value,
    $Res Function(_$MumbleEvent_ConnectedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$MumbleEvent_ConnectedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$MumbleEvent_ConnectedImpl extends MumbleEvent_Connected {
  const _$MumbleEvent_ConnectedImpl(this.field0) : super._();

  @override
  final int field0;

  @override
  String toString() {
    return 'MumbleEvent.connected(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MumbleEvent_ConnectedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MumbleEvent_ConnectedImplCopyWith<_$MumbleEvent_ConnectedImpl>
  get copyWith =>
      __$$MumbleEvent_ConnectedImplCopyWithImpl<_$MumbleEvent_ConnectedImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int field0) connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(MumbleChannel field0) channelUpdate,
    required TResult Function(MumbleUser field0) userUpdate,
    required TResult Function(int field0) userRemoved,
    required TResult Function(MumbleTextMessage field0) textMessage,
    required TResult Function(double field0) audioVolume,
  }) {
    return connected(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int field0)? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(MumbleChannel field0)? channelUpdate,
    TResult? Function(MumbleUser field0)? userUpdate,
    TResult? Function(int field0)? userRemoved,
    TResult? Function(MumbleTextMessage field0)? textMessage,
    TResult? Function(double field0)? audioVolume,
  }) {
    return connected?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int field0)? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(MumbleChannel field0)? channelUpdate,
    TResult Function(MumbleUser field0)? userUpdate,
    TResult Function(int field0)? userRemoved,
    TResult Function(MumbleTextMessage field0)? textMessage,
    TResult Function(double field0)? audioVolume,
    required TResult orElse(),
  }) {
    if (connected != null) {
      return connected(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MumbleEvent_Connected value) connected,
    required TResult Function(MumbleEvent_Disconnected value) disconnected,
    required TResult Function(MumbleEvent_ChannelUpdate value) channelUpdate,
    required TResult Function(MumbleEvent_UserUpdate value) userUpdate,
    required TResult Function(MumbleEvent_UserRemoved value) userRemoved,
    required TResult Function(MumbleEvent_TextMessage value) textMessage,
    required TResult Function(MumbleEvent_AudioVolume value) audioVolume,
  }) {
    return connected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MumbleEvent_Connected value)? connected,
    TResult? Function(MumbleEvent_Disconnected value)? disconnected,
    TResult? Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult? Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult? Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult? Function(MumbleEvent_TextMessage value)? textMessage,
    TResult? Function(MumbleEvent_AudioVolume value)? audioVolume,
  }) {
    return connected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MumbleEvent_Connected value)? connected,
    TResult Function(MumbleEvent_Disconnected value)? disconnected,
    TResult Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult Function(MumbleEvent_TextMessage value)? textMessage,
    TResult Function(MumbleEvent_AudioVolume value)? audioVolume,
    required TResult orElse(),
  }) {
    if (connected != null) {
      return connected(this);
    }
    return orElse();
  }
}

abstract class MumbleEvent_Connected extends MumbleEvent {
  const factory MumbleEvent_Connected(final int field0) =
      _$MumbleEvent_ConnectedImpl;
  const MumbleEvent_Connected._() : super._();

  @override
  int get field0;

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MumbleEvent_ConnectedImplCopyWith<_$MumbleEvent_ConnectedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MumbleEvent_DisconnectedImplCopyWith<$Res> {
  factory _$$MumbleEvent_DisconnectedImplCopyWith(
    _$MumbleEvent_DisconnectedImpl value,
    $Res Function(_$MumbleEvent_DisconnectedImpl) then,
  ) = __$$MumbleEvent_DisconnectedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$MumbleEvent_DisconnectedImplCopyWithImpl<$Res>
    extends _$MumbleEventCopyWithImpl<$Res, _$MumbleEvent_DisconnectedImpl>
    implements _$$MumbleEvent_DisconnectedImplCopyWith<$Res> {
  __$$MumbleEvent_DisconnectedImplCopyWithImpl(
    _$MumbleEvent_DisconnectedImpl _value,
    $Res Function(_$MumbleEvent_DisconnectedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$MumbleEvent_DisconnectedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$MumbleEvent_DisconnectedImpl extends MumbleEvent_Disconnected {
  const _$MumbleEvent_DisconnectedImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'MumbleEvent.disconnected(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MumbleEvent_DisconnectedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MumbleEvent_DisconnectedImplCopyWith<_$MumbleEvent_DisconnectedImpl>
  get copyWith =>
      __$$MumbleEvent_DisconnectedImplCopyWithImpl<
        _$MumbleEvent_DisconnectedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int field0) connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(MumbleChannel field0) channelUpdate,
    required TResult Function(MumbleUser field0) userUpdate,
    required TResult Function(int field0) userRemoved,
    required TResult Function(MumbleTextMessage field0) textMessage,
    required TResult Function(double field0) audioVolume,
  }) {
    return disconnected(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int field0)? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(MumbleChannel field0)? channelUpdate,
    TResult? Function(MumbleUser field0)? userUpdate,
    TResult? Function(int field0)? userRemoved,
    TResult? Function(MumbleTextMessage field0)? textMessage,
    TResult? Function(double field0)? audioVolume,
  }) {
    return disconnected?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int field0)? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(MumbleChannel field0)? channelUpdate,
    TResult Function(MumbleUser field0)? userUpdate,
    TResult Function(int field0)? userRemoved,
    TResult Function(MumbleTextMessage field0)? textMessage,
    TResult Function(double field0)? audioVolume,
    required TResult orElse(),
  }) {
    if (disconnected != null) {
      return disconnected(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MumbleEvent_Connected value) connected,
    required TResult Function(MumbleEvent_Disconnected value) disconnected,
    required TResult Function(MumbleEvent_ChannelUpdate value) channelUpdate,
    required TResult Function(MumbleEvent_UserUpdate value) userUpdate,
    required TResult Function(MumbleEvent_UserRemoved value) userRemoved,
    required TResult Function(MumbleEvent_TextMessage value) textMessage,
    required TResult Function(MumbleEvent_AudioVolume value) audioVolume,
  }) {
    return disconnected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MumbleEvent_Connected value)? connected,
    TResult? Function(MumbleEvent_Disconnected value)? disconnected,
    TResult? Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult? Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult? Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult? Function(MumbleEvent_TextMessage value)? textMessage,
    TResult? Function(MumbleEvent_AudioVolume value)? audioVolume,
  }) {
    return disconnected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MumbleEvent_Connected value)? connected,
    TResult Function(MumbleEvent_Disconnected value)? disconnected,
    TResult Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult Function(MumbleEvent_TextMessage value)? textMessage,
    TResult Function(MumbleEvent_AudioVolume value)? audioVolume,
    required TResult orElse(),
  }) {
    if (disconnected != null) {
      return disconnected(this);
    }
    return orElse();
  }
}

abstract class MumbleEvent_Disconnected extends MumbleEvent {
  const factory MumbleEvent_Disconnected(final String field0) =
      _$MumbleEvent_DisconnectedImpl;
  const MumbleEvent_Disconnected._() : super._();

  @override
  String get field0;

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MumbleEvent_DisconnectedImplCopyWith<_$MumbleEvent_DisconnectedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MumbleEvent_ChannelUpdateImplCopyWith<$Res> {
  factory _$$MumbleEvent_ChannelUpdateImplCopyWith(
    _$MumbleEvent_ChannelUpdateImpl value,
    $Res Function(_$MumbleEvent_ChannelUpdateImpl) then,
  ) = __$$MumbleEvent_ChannelUpdateImplCopyWithImpl<$Res>;
  @useResult
  $Res call({MumbleChannel field0});
}

/// @nodoc
class __$$MumbleEvent_ChannelUpdateImplCopyWithImpl<$Res>
    extends _$MumbleEventCopyWithImpl<$Res, _$MumbleEvent_ChannelUpdateImpl>
    implements _$$MumbleEvent_ChannelUpdateImplCopyWith<$Res> {
  __$$MumbleEvent_ChannelUpdateImplCopyWithImpl(
    _$MumbleEvent_ChannelUpdateImpl _value,
    $Res Function(_$MumbleEvent_ChannelUpdateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$MumbleEvent_ChannelUpdateImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as MumbleChannel,
      ),
    );
  }
}

/// @nodoc

class _$MumbleEvent_ChannelUpdateImpl extends MumbleEvent_ChannelUpdate {
  const _$MumbleEvent_ChannelUpdateImpl(this.field0) : super._();

  @override
  final MumbleChannel field0;

  @override
  String toString() {
    return 'MumbleEvent.channelUpdate(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MumbleEvent_ChannelUpdateImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MumbleEvent_ChannelUpdateImplCopyWith<_$MumbleEvent_ChannelUpdateImpl>
  get copyWith =>
      __$$MumbleEvent_ChannelUpdateImplCopyWithImpl<
        _$MumbleEvent_ChannelUpdateImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int field0) connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(MumbleChannel field0) channelUpdate,
    required TResult Function(MumbleUser field0) userUpdate,
    required TResult Function(int field0) userRemoved,
    required TResult Function(MumbleTextMessage field0) textMessage,
    required TResult Function(double field0) audioVolume,
  }) {
    return channelUpdate(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int field0)? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(MumbleChannel field0)? channelUpdate,
    TResult? Function(MumbleUser field0)? userUpdate,
    TResult? Function(int field0)? userRemoved,
    TResult? Function(MumbleTextMessage field0)? textMessage,
    TResult? Function(double field0)? audioVolume,
  }) {
    return channelUpdate?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int field0)? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(MumbleChannel field0)? channelUpdate,
    TResult Function(MumbleUser field0)? userUpdate,
    TResult Function(int field0)? userRemoved,
    TResult Function(MumbleTextMessage field0)? textMessage,
    TResult Function(double field0)? audioVolume,
    required TResult orElse(),
  }) {
    if (channelUpdate != null) {
      return channelUpdate(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MumbleEvent_Connected value) connected,
    required TResult Function(MumbleEvent_Disconnected value) disconnected,
    required TResult Function(MumbleEvent_ChannelUpdate value) channelUpdate,
    required TResult Function(MumbleEvent_UserUpdate value) userUpdate,
    required TResult Function(MumbleEvent_UserRemoved value) userRemoved,
    required TResult Function(MumbleEvent_TextMessage value) textMessage,
    required TResult Function(MumbleEvent_AudioVolume value) audioVolume,
  }) {
    return channelUpdate(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MumbleEvent_Connected value)? connected,
    TResult? Function(MumbleEvent_Disconnected value)? disconnected,
    TResult? Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult? Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult? Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult? Function(MumbleEvent_TextMessage value)? textMessage,
    TResult? Function(MumbleEvent_AudioVolume value)? audioVolume,
  }) {
    return channelUpdate?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MumbleEvent_Connected value)? connected,
    TResult Function(MumbleEvent_Disconnected value)? disconnected,
    TResult Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult Function(MumbleEvent_TextMessage value)? textMessage,
    TResult Function(MumbleEvent_AudioVolume value)? audioVolume,
    required TResult orElse(),
  }) {
    if (channelUpdate != null) {
      return channelUpdate(this);
    }
    return orElse();
  }
}

abstract class MumbleEvent_ChannelUpdate extends MumbleEvent {
  const factory MumbleEvent_ChannelUpdate(final MumbleChannel field0) =
      _$MumbleEvent_ChannelUpdateImpl;
  const MumbleEvent_ChannelUpdate._() : super._();

  @override
  MumbleChannel get field0;

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MumbleEvent_ChannelUpdateImplCopyWith<_$MumbleEvent_ChannelUpdateImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MumbleEvent_UserUpdateImplCopyWith<$Res> {
  factory _$$MumbleEvent_UserUpdateImplCopyWith(
    _$MumbleEvent_UserUpdateImpl value,
    $Res Function(_$MumbleEvent_UserUpdateImpl) then,
  ) = __$$MumbleEvent_UserUpdateImplCopyWithImpl<$Res>;
  @useResult
  $Res call({MumbleUser field0});
}

/// @nodoc
class __$$MumbleEvent_UserUpdateImplCopyWithImpl<$Res>
    extends _$MumbleEventCopyWithImpl<$Res, _$MumbleEvent_UserUpdateImpl>
    implements _$$MumbleEvent_UserUpdateImplCopyWith<$Res> {
  __$$MumbleEvent_UserUpdateImplCopyWithImpl(
    _$MumbleEvent_UserUpdateImpl _value,
    $Res Function(_$MumbleEvent_UserUpdateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$MumbleEvent_UserUpdateImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as MumbleUser,
      ),
    );
  }
}

/// @nodoc

class _$MumbleEvent_UserUpdateImpl extends MumbleEvent_UserUpdate {
  const _$MumbleEvent_UserUpdateImpl(this.field0) : super._();

  @override
  final MumbleUser field0;

  @override
  String toString() {
    return 'MumbleEvent.userUpdate(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MumbleEvent_UserUpdateImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MumbleEvent_UserUpdateImplCopyWith<_$MumbleEvent_UserUpdateImpl>
  get copyWith =>
      __$$MumbleEvent_UserUpdateImplCopyWithImpl<_$MumbleEvent_UserUpdateImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int field0) connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(MumbleChannel field0) channelUpdate,
    required TResult Function(MumbleUser field0) userUpdate,
    required TResult Function(int field0) userRemoved,
    required TResult Function(MumbleTextMessage field0) textMessage,
    required TResult Function(double field0) audioVolume,
  }) {
    return userUpdate(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int field0)? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(MumbleChannel field0)? channelUpdate,
    TResult? Function(MumbleUser field0)? userUpdate,
    TResult? Function(int field0)? userRemoved,
    TResult? Function(MumbleTextMessage field0)? textMessage,
    TResult? Function(double field0)? audioVolume,
  }) {
    return userUpdate?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int field0)? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(MumbleChannel field0)? channelUpdate,
    TResult Function(MumbleUser field0)? userUpdate,
    TResult Function(int field0)? userRemoved,
    TResult Function(MumbleTextMessage field0)? textMessage,
    TResult Function(double field0)? audioVolume,
    required TResult orElse(),
  }) {
    if (userUpdate != null) {
      return userUpdate(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MumbleEvent_Connected value) connected,
    required TResult Function(MumbleEvent_Disconnected value) disconnected,
    required TResult Function(MumbleEvent_ChannelUpdate value) channelUpdate,
    required TResult Function(MumbleEvent_UserUpdate value) userUpdate,
    required TResult Function(MumbleEvent_UserRemoved value) userRemoved,
    required TResult Function(MumbleEvent_TextMessage value) textMessage,
    required TResult Function(MumbleEvent_AudioVolume value) audioVolume,
  }) {
    return userUpdate(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MumbleEvent_Connected value)? connected,
    TResult? Function(MumbleEvent_Disconnected value)? disconnected,
    TResult? Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult? Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult? Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult? Function(MumbleEvent_TextMessage value)? textMessage,
    TResult? Function(MumbleEvent_AudioVolume value)? audioVolume,
  }) {
    return userUpdate?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MumbleEvent_Connected value)? connected,
    TResult Function(MumbleEvent_Disconnected value)? disconnected,
    TResult Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult Function(MumbleEvent_TextMessage value)? textMessage,
    TResult Function(MumbleEvent_AudioVolume value)? audioVolume,
    required TResult orElse(),
  }) {
    if (userUpdate != null) {
      return userUpdate(this);
    }
    return orElse();
  }
}

abstract class MumbleEvent_UserUpdate extends MumbleEvent {
  const factory MumbleEvent_UserUpdate(final MumbleUser field0) =
      _$MumbleEvent_UserUpdateImpl;
  const MumbleEvent_UserUpdate._() : super._();

  @override
  MumbleUser get field0;

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MumbleEvent_UserUpdateImplCopyWith<_$MumbleEvent_UserUpdateImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MumbleEvent_UserRemovedImplCopyWith<$Res> {
  factory _$$MumbleEvent_UserRemovedImplCopyWith(
    _$MumbleEvent_UserRemovedImpl value,
    $Res Function(_$MumbleEvent_UserRemovedImpl) then,
  ) = __$$MumbleEvent_UserRemovedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int field0});
}

/// @nodoc
class __$$MumbleEvent_UserRemovedImplCopyWithImpl<$Res>
    extends _$MumbleEventCopyWithImpl<$Res, _$MumbleEvent_UserRemovedImpl>
    implements _$$MumbleEvent_UserRemovedImplCopyWith<$Res> {
  __$$MumbleEvent_UserRemovedImplCopyWithImpl(
    _$MumbleEvent_UserRemovedImpl _value,
    $Res Function(_$MumbleEvent_UserRemovedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$MumbleEvent_UserRemovedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$MumbleEvent_UserRemovedImpl extends MumbleEvent_UserRemoved {
  const _$MumbleEvent_UserRemovedImpl(this.field0) : super._();

  @override
  final int field0;

  @override
  String toString() {
    return 'MumbleEvent.userRemoved(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MumbleEvent_UserRemovedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MumbleEvent_UserRemovedImplCopyWith<_$MumbleEvent_UserRemovedImpl>
  get copyWith =>
      __$$MumbleEvent_UserRemovedImplCopyWithImpl<
        _$MumbleEvent_UserRemovedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int field0) connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(MumbleChannel field0) channelUpdate,
    required TResult Function(MumbleUser field0) userUpdate,
    required TResult Function(int field0) userRemoved,
    required TResult Function(MumbleTextMessage field0) textMessage,
    required TResult Function(double field0) audioVolume,
  }) {
    return userRemoved(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int field0)? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(MumbleChannel field0)? channelUpdate,
    TResult? Function(MumbleUser field0)? userUpdate,
    TResult? Function(int field0)? userRemoved,
    TResult? Function(MumbleTextMessage field0)? textMessage,
    TResult? Function(double field0)? audioVolume,
  }) {
    return userRemoved?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int field0)? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(MumbleChannel field0)? channelUpdate,
    TResult Function(MumbleUser field0)? userUpdate,
    TResult Function(int field0)? userRemoved,
    TResult Function(MumbleTextMessage field0)? textMessage,
    TResult Function(double field0)? audioVolume,
    required TResult orElse(),
  }) {
    if (userRemoved != null) {
      return userRemoved(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MumbleEvent_Connected value) connected,
    required TResult Function(MumbleEvent_Disconnected value) disconnected,
    required TResult Function(MumbleEvent_ChannelUpdate value) channelUpdate,
    required TResult Function(MumbleEvent_UserUpdate value) userUpdate,
    required TResult Function(MumbleEvent_UserRemoved value) userRemoved,
    required TResult Function(MumbleEvent_TextMessage value) textMessage,
    required TResult Function(MumbleEvent_AudioVolume value) audioVolume,
  }) {
    return userRemoved(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MumbleEvent_Connected value)? connected,
    TResult? Function(MumbleEvent_Disconnected value)? disconnected,
    TResult? Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult? Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult? Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult? Function(MumbleEvent_TextMessage value)? textMessage,
    TResult? Function(MumbleEvent_AudioVolume value)? audioVolume,
  }) {
    return userRemoved?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MumbleEvent_Connected value)? connected,
    TResult Function(MumbleEvent_Disconnected value)? disconnected,
    TResult Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult Function(MumbleEvent_TextMessage value)? textMessage,
    TResult Function(MumbleEvent_AudioVolume value)? audioVolume,
    required TResult orElse(),
  }) {
    if (userRemoved != null) {
      return userRemoved(this);
    }
    return orElse();
  }
}

abstract class MumbleEvent_UserRemoved extends MumbleEvent {
  const factory MumbleEvent_UserRemoved(final int field0) =
      _$MumbleEvent_UserRemovedImpl;
  const MumbleEvent_UserRemoved._() : super._();

  @override
  int get field0;

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MumbleEvent_UserRemovedImplCopyWith<_$MumbleEvent_UserRemovedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MumbleEvent_TextMessageImplCopyWith<$Res> {
  factory _$$MumbleEvent_TextMessageImplCopyWith(
    _$MumbleEvent_TextMessageImpl value,
    $Res Function(_$MumbleEvent_TextMessageImpl) then,
  ) = __$$MumbleEvent_TextMessageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({MumbleTextMessage field0});
}

/// @nodoc
class __$$MumbleEvent_TextMessageImplCopyWithImpl<$Res>
    extends _$MumbleEventCopyWithImpl<$Res, _$MumbleEvent_TextMessageImpl>
    implements _$$MumbleEvent_TextMessageImplCopyWith<$Res> {
  __$$MumbleEvent_TextMessageImplCopyWithImpl(
    _$MumbleEvent_TextMessageImpl _value,
    $Res Function(_$MumbleEvent_TextMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$MumbleEvent_TextMessageImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as MumbleTextMessage,
      ),
    );
  }
}

/// @nodoc

class _$MumbleEvent_TextMessageImpl extends MumbleEvent_TextMessage {
  const _$MumbleEvent_TextMessageImpl(this.field0) : super._();

  @override
  final MumbleTextMessage field0;

  @override
  String toString() {
    return 'MumbleEvent.textMessage(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MumbleEvent_TextMessageImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MumbleEvent_TextMessageImplCopyWith<_$MumbleEvent_TextMessageImpl>
  get copyWith =>
      __$$MumbleEvent_TextMessageImplCopyWithImpl<
        _$MumbleEvent_TextMessageImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int field0) connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(MumbleChannel field0) channelUpdate,
    required TResult Function(MumbleUser field0) userUpdate,
    required TResult Function(int field0) userRemoved,
    required TResult Function(MumbleTextMessage field0) textMessage,
    required TResult Function(double field0) audioVolume,
  }) {
    return textMessage(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int field0)? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(MumbleChannel field0)? channelUpdate,
    TResult? Function(MumbleUser field0)? userUpdate,
    TResult? Function(int field0)? userRemoved,
    TResult? Function(MumbleTextMessage field0)? textMessage,
    TResult? Function(double field0)? audioVolume,
  }) {
    return textMessage?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int field0)? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(MumbleChannel field0)? channelUpdate,
    TResult Function(MumbleUser field0)? userUpdate,
    TResult Function(int field0)? userRemoved,
    TResult Function(MumbleTextMessage field0)? textMessage,
    TResult Function(double field0)? audioVolume,
    required TResult orElse(),
  }) {
    if (textMessage != null) {
      return textMessage(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MumbleEvent_Connected value) connected,
    required TResult Function(MumbleEvent_Disconnected value) disconnected,
    required TResult Function(MumbleEvent_ChannelUpdate value) channelUpdate,
    required TResult Function(MumbleEvent_UserUpdate value) userUpdate,
    required TResult Function(MumbleEvent_UserRemoved value) userRemoved,
    required TResult Function(MumbleEvent_TextMessage value) textMessage,
    required TResult Function(MumbleEvent_AudioVolume value) audioVolume,
  }) {
    return textMessage(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MumbleEvent_Connected value)? connected,
    TResult? Function(MumbleEvent_Disconnected value)? disconnected,
    TResult? Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult? Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult? Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult? Function(MumbleEvent_TextMessage value)? textMessage,
    TResult? Function(MumbleEvent_AudioVolume value)? audioVolume,
  }) {
    return textMessage?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MumbleEvent_Connected value)? connected,
    TResult Function(MumbleEvent_Disconnected value)? disconnected,
    TResult Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult Function(MumbleEvent_TextMessage value)? textMessage,
    TResult Function(MumbleEvent_AudioVolume value)? audioVolume,
    required TResult orElse(),
  }) {
    if (textMessage != null) {
      return textMessage(this);
    }
    return orElse();
  }
}

abstract class MumbleEvent_TextMessage extends MumbleEvent {
  const factory MumbleEvent_TextMessage(final MumbleTextMessage field0) =
      _$MumbleEvent_TextMessageImpl;
  const MumbleEvent_TextMessage._() : super._();

  @override
  MumbleTextMessage get field0;

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MumbleEvent_TextMessageImplCopyWith<_$MumbleEvent_TextMessageImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MumbleEvent_AudioVolumeImplCopyWith<$Res> {
  factory _$$MumbleEvent_AudioVolumeImplCopyWith(
    _$MumbleEvent_AudioVolumeImpl value,
    $Res Function(_$MumbleEvent_AudioVolumeImpl) then,
  ) = __$$MumbleEvent_AudioVolumeImplCopyWithImpl<$Res>;
  @useResult
  $Res call({double field0});
}

/// @nodoc
class __$$MumbleEvent_AudioVolumeImplCopyWithImpl<$Res>
    extends _$MumbleEventCopyWithImpl<$Res, _$MumbleEvent_AudioVolumeImpl>
    implements _$$MumbleEvent_AudioVolumeImplCopyWith<$Res> {
  __$$MumbleEvent_AudioVolumeImplCopyWithImpl(
    _$MumbleEvent_AudioVolumeImpl _value,
    $Res Function(_$MumbleEvent_AudioVolumeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$MumbleEvent_AudioVolumeImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$MumbleEvent_AudioVolumeImpl extends MumbleEvent_AudioVolume {
  const _$MumbleEvent_AudioVolumeImpl(this.field0) : super._();

  @override
  final double field0;

  @override
  String toString() {
    return 'MumbleEvent.audioVolume(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MumbleEvent_AudioVolumeImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MumbleEvent_AudioVolumeImplCopyWith<_$MumbleEvent_AudioVolumeImpl>
  get copyWith =>
      __$$MumbleEvent_AudioVolumeImplCopyWithImpl<
        _$MumbleEvent_AudioVolumeImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int field0) connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(MumbleChannel field0) channelUpdate,
    required TResult Function(MumbleUser field0) userUpdate,
    required TResult Function(int field0) userRemoved,
    required TResult Function(MumbleTextMessage field0) textMessage,
    required TResult Function(double field0) audioVolume,
  }) {
    return audioVolume(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int field0)? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(MumbleChannel field0)? channelUpdate,
    TResult? Function(MumbleUser field0)? userUpdate,
    TResult? Function(int field0)? userRemoved,
    TResult? Function(MumbleTextMessage field0)? textMessage,
    TResult? Function(double field0)? audioVolume,
  }) {
    return audioVolume?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int field0)? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(MumbleChannel field0)? channelUpdate,
    TResult Function(MumbleUser field0)? userUpdate,
    TResult Function(int field0)? userRemoved,
    TResult Function(MumbleTextMessage field0)? textMessage,
    TResult Function(double field0)? audioVolume,
    required TResult orElse(),
  }) {
    if (audioVolume != null) {
      return audioVolume(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MumbleEvent_Connected value) connected,
    required TResult Function(MumbleEvent_Disconnected value) disconnected,
    required TResult Function(MumbleEvent_ChannelUpdate value) channelUpdate,
    required TResult Function(MumbleEvent_UserUpdate value) userUpdate,
    required TResult Function(MumbleEvent_UserRemoved value) userRemoved,
    required TResult Function(MumbleEvent_TextMessage value) textMessage,
    required TResult Function(MumbleEvent_AudioVolume value) audioVolume,
  }) {
    return audioVolume(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MumbleEvent_Connected value)? connected,
    TResult? Function(MumbleEvent_Disconnected value)? disconnected,
    TResult? Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult? Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult? Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult? Function(MumbleEvent_TextMessage value)? textMessage,
    TResult? Function(MumbleEvent_AudioVolume value)? audioVolume,
  }) {
    return audioVolume?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MumbleEvent_Connected value)? connected,
    TResult Function(MumbleEvent_Disconnected value)? disconnected,
    TResult Function(MumbleEvent_ChannelUpdate value)? channelUpdate,
    TResult Function(MumbleEvent_UserUpdate value)? userUpdate,
    TResult Function(MumbleEvent_UserRemoved value)? userRemoved,
    TResult Function(MumbleEvent_TextMessage value)? textMessage,
    TResult Function(MumbleEvent_AudioVolume value)? audioVolume,
    required TResult orElse(),
  }) {
    if (audioVolume != null) {
      return audioVolume(this);
    }
    return orElse();
  }
}

abstract class MumbleEvent_AudioVolume extends MumbleEvent {
  const factory MumbleEvent_AudioVolume(final double field0) =
      _$MumbleEvent_AudioVolumeImpl;
  const MumbleEvent_AudioVolume._() : super._();

  @override
  double get field0;

  /// Create a copy of MumbleEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MumbleEvent_AudioVolumeImplCopyWith<_$MumbleEvent_AudioVolumeImpl>
  get copyWith => throw _privateConstructorUsedError;
}
