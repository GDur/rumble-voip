// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'types.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AudioBufferSize {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioBufferSize);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AudioBufferSize()';
}


}

/// @nodoc
class $AudioBufferSizeCopyWith<$Res>  {
$AudioBufferSizeCopyWith(AudioBufferSize _, $Res Function(AudioBufferSize) __);
}


/// Adds pattern-matching-related methods to [AudioBufferSize].
extension AudioBufferSizePatterns on AudioBufferSize {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AudioBufferSize_Default value)?  default_,TResult Function( AudioBufferSize_Fixed value)?  fixed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AudioBufferSize_Default() when default_ != null:
return default_(_that);case AudioBufferSize_Fixed() when fixed != null:
return fixed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AudioBufferSize_Default value)  default_,required TResult Function( AudioBufferSize_Fixed value)  fixed,}){
final _that = this;
switch (_that) {
case AudioBufferSize_Default():
return default_(_that);case AudioBufferSize_Fixed():
return fixed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AudioBufferSize_Default value)?  default_,TResult? Function( AudioBufferSize_Fixed value)?  fixed,}){
final _that = this;
switch (_that) {
case AudioBufferSize_Default() when default_ != null:
return default_(_that);case AudioBufferSize_Fixed() when fixed != null:
return fixed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  default_,TResult Function( int field0)?  fixed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AudioBufferSize_Default() when default_ != null:
return default_();case AudioBufferSize_Fixed() when fixed != null:
return fixed(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  default_,required TResult Function( int field0)  fixed,}) {final _that = this;
switch (_that) {
case AudioBufferSize_Default():
return default_();case AudioBufferSize_Fixed():
return fixed(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  default_,TResult? Function( int field0)?  fixed,}) {final _that = this;
switch (_that) {
case AudioBufferSize_Default() when default_ != null:
return default_();case AudioBufferSize_Fixed() when fixed != null:
return fixed(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class AudioBufferSize_Default extends AudioBufferSize {
  const AudioBufferSize_Default(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioBufferSize_Default);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AudioBufferSize.default_()';
}


}




/// @nodoc


class AudioBufferSize_Fixed extends AudioBufferSize {
  const AudioBufferSize_Fixed(this.field0): super._();
  

 final  int field0;

/// Create a copy of AudioBufferSize
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioBufferSize_FixedCopyWith<AudioBufferSize_Fixed> get copyWith => _$AudioBufferSize_FixedCopyWithImpl<AudioBufferSize_Fixed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioBufferSize_Fixed&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'AudioBufferSize.fixed(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $AudioBufferSize_FixedCopyWith<$Res> implements $AudioBufferSizeCopyWith<$Res> {
  factory $AudioBufferSize_FixedCopyWith(AudioBufferSize_Fixed value, $Res Function(AudioBufferSize_Fixed) _then) = _$AudioBufferSize_FixedCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$AudioBufferSize_FixedCopyWithImpl<$Res>
    implements $AudioBufferSize_FixedCopyWith<$Res> {
  _$AudioBufferSize_FixedCopyWithImpl(this._self, this._then);

  final AudioBufferSize_Fixed _self;
  final $Res Function(AudioBufferSize_Fixed) _then;

/// Create a copy of AudioBufferSize
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(AudioBufferSize_Fixed(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
