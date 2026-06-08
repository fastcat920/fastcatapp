// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'xboard_send_email_code_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

VerificationCodeResponse _$VerificationCodeResponseFromJson(
    Map<String, dynamic> json) {
  return _VerificationCodeResponse.fromJson(json);
}

/// @nodoc
mixin _$VerificationCodeResponse {
  bool get success => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;

  /// Serializes this VerificationCodeResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VerificationCodeResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VerificationCodeResponseCopyWith<VerificationCodeResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VerificationCodeResponseCopyWith<$Res> {
  factory $VerificationCodeResponseCopyWith(VerificationCodeResponse value,
          $Res Function(VerificationCodeResponse) then) =
      _$VerificationCodeResponseCopyWithImpl<$Res, VerificationCodeResponse>;
  @useResult
  $Res call({bool success, String? message});
}

/// @nodoc
class _$VerificationCodeResponseCopyWithImpl<$Res,
        $Val extends VerificationCodeResponse>
    implements $VerificationCodeResponseCopyWith<$Res> {
  _$VerificationCodeResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VerificationCodeResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? message = freezed,
  }) {
    return _then(_value.copyWith(
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VerificationCodeResponseImplCopyWith<$Res>
    implements $VerificationCodeResponseCopyWith<$Res> {
  factory _$$VerificationCodeResponseImplCopyWith(
          _$VerificationCodeResponseImpl value,
          $Res Function(_$VerificationCodeResponseImpl) then) =
      __$$VerificationCodeResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool success, String? message});
}

/// @nodoc
class __$$VerificationCodeResponseImplCopyWithImpl<$Res>
    extends _$VerificationCodeResponseCopyWithImpl<$Res,
        _$VerificationCodeResponseImpl>
    implements _$$VerificationCodeResponseImplCopyWith<$Res> {
  __$$VerificationCodeResponseImplCopyWithImpl(
      _$VerificationCodeResponseImpl _value,
      $Res Function(_$VerificationCodeResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of VerificationCodeResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? message = freezed,
  }) {
    return _then(_$VerificationCodeResponseImpl(
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VerificationCodeResponseImpl implements _VerificationCodeResponse {
  const _$VerificationCodeResponseImpl({required this.success, this.message});

  factory _$VerificationCodeResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$VerificationCodeResponseImplFromJson(json);

  @override
  final bool success;
  @override
  final String? message;

  @override
  String toString() {
    return 'VerificationCodeResponse(success: $success, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VerificationCodeResponseImpl &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, success, message);

  /// Create a copy of VerificationCodeResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VerificationCodeResponseImplCopyWith<_$VerificationCodeResponseImpl>
      get copyWith => __$$VerificationCodeResponseImplCopyWithImpl<
          _$VerificationCodeResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VerificationCodeResponseImplToJson(
      this,
    );
  }
}

abstract class _VerificationCodeResponse implements VerificationCodeResponse {
  const factory _VerificationCodeResponse(
      {required final bool success,
      final String? message}) = _$VerificationCodeResponseImpl;

  factory _VerificationCodeResponse.fromJson(Map<String, dynamic> json) =
      _$VerificationCodeResponseImpl.fromJson;

  @override
  bool get success;
  @override
  String? get message;

  /// Create a copy of VerificationCodeResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VerificationCodeResponseImplCopyWith<_$VerificationCodeResponseImpl>
      get copyWith => throw _privateConstructorUsedError;
}
