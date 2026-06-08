// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PaymentMethodModel _$PaymentMethodModelFromJson(Map<String, dynamic> json) {
  return _PaymentMethodModel.fromJson(json);
}

/// @nodoc
mixin _$PaymentMethodModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'payment')
  String? get paymentMethod =>
      throw _privateConstructorUsedError; // API字段为payment
  @JsonKey(name: 'handling_fee_fixed')
  double? get handlingFeeFixed => throw _privateConstructorUsedError;
  @JsonKey(name: 'handling_fee_percent')
  double? get handlingFeePercent => throw _privateConstructorUsedError;
  String? get icon => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_available')
  bool get isAvailable => throw _privateConstructorUsedError;
  Map<String, dynamic>? get config => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'min_amount')
  double? get minAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'max_amount')
  double? get maxAmount => throw _privateConstructorUsedError;

  /// Serializes this PaymentMethodModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PaymentMethodModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaymentMethodModelCopyWith<PaymentMethodModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentMethodModelCopyWith<$Res> {
  factory $PaymentMethodModelCopyWith(
          PaymentMethodModel value, $Res Function(PaymentMethodModel) then) =
      _$PaymentMethodModelCopyWithImpl<$Res, PaymentMethodModel>;
  @useResult
  $Res call(
      {String id,
      String name,
      @JsonKey(name: 'payment') String? paymentMethod,
      @JsonKey(name: 'handling_fee_fixed') double? handlingFeeFixed,
      @JsonKey(name: 'handling_fee_percent') double? handlingFeePercent,
      String? icon,
      @JsonKey(name: 'is_available') bool isAvailable,
      Map<String, dynamic>? config,
      String? description,
      @JsonKey(name: 'min_amount') double? minAmount,
      @JsonKey(name: 'max_amount') double? maxAmount});
}

/// @nodoc
class _$PaymentMethodModelCopyWithImpl<$Res, $Val extends PaymentMethodModel>
    implements $PaymentMethodModelCopyWith<$Res> {
  _$PaymentMethodModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentMethodModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? paymentMethod = freezed,
    Object? handlingFeeFixed = freezed,
    Object? handlingFeePercent = freezed,
    Object? icon = freezed,
    Object? isAvailable = null,
    Object? config = freezed,
    Object? description = freezed,
    Object? minAmount = freezed,
    Object? maxAmount = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      paymentMethod: freezed == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String?,
      handlingFeeFixed: freezed == handlingFeeFixed
          ? _value.handlingFeeFixed
          : handlingFeeFixed // ignore: cast_nullable_to_non_nullable
              as double?,
      handlingFeePercent: freezed == handlingFeePercent
          ? _value.handlingFeePercent
          : handlingFeePercent // ignore: cast_nullable_to_non_nullable
              as double?,
      icon: freezed == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String?,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      config: freezed == config
          ? _value.config
          : config // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      minAmount: freezed == minAmount
          ? _value.minAmount
          : minAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      maxAmount: freezed == maxAmount
          ? _value.maxAmount
          : maxAmount // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PaymentMethodModelImplCopyWith<$Res>
    implements $PaymentMethodModelCopyWith<$Res> {
  factory _$$PaymentMethodModelImplCopyWith(_$PaymentMethodModelImpl value,
          $Res Function(_$PaymentMethodModelImpl) then) =
      __$$PaymentMethodModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      @JsonKey(name: 'payment') String? paymentMethod,
      @JsonKey(name: 'handling_fee_fixed') double? handlingFeeFixed,
      @JsonKey(name: 'handling_fee_percent') double? handlingFeePercent,
      String? icon,
      @JsonKey(name: 'is_available') bool isAvailable,
      Map<String, dynamic>? config,
      String? description,
      @JsonKey(name: 'min_amount') double? minAmount,
      @JsonKey(name: 'max_amount') double? maxAmount});
}

/// @nodoc
class __$$PaymentMethodModelImplCopyWithImpl<$Res>
    extends _$PaymentMethodModelCopyWithImpl<$Res, _$PaymentMethodModelImpl>
    implements _$$PaymentMethodModelImplCopyWith<$Res> {
  __$$PaymentMethodModelImplCopyWithImpl(_$PaymentMethodModelImpl _value,
      $Res Function(_$PaymentMethodModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentMethodModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? paymentMethod = freezed,
    Object? handlingFeeFixed = freezed,
    Object? handlingFeePercent = freezed,
    Object? icon = freezed,
    Object? isAvailable = null,
    Object? config = freezed,
    Object? description = freezed,
    Object? minAmount = freezed,
    Object? maxAmount = freezed,
  }) {
    return _then(_$PaymentMethodModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      paymentMethod: freezed == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String?,
      handlingFeeFixed: freezed == handlingFeeFixed
          ? _value.handlingFeeFixed
          : handlingFeeFixed // ignore: cast_nullable_to_non_nullable
              as double?,
      handlingFeePercent: freezed == handlingFeePercent
          ? _value.handlingFeePercent
          : handlingFeePercent // ignore: cast_nullable_to_non_nullable
              as double?,
      icon: freezed == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String?,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      config: freezed == config
          ? _value._config
          : config // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      minAmount: freezed == minAmount
          ? _value.minAmount
          : minAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      maxAmount: freezed == maxAmount
          ? _value.maxAmount
          : maxAmount // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaymentMethodModelImpl extends _PaymentMethodModel {
  const _$PaymentMethodModelImpl(
      {required this.id,
      required this.name,
      @JsonKey(name: 'payment') this.paymentMethod,
      @JsonKey(name: 'handling_fee_fixed') this.handlingFeeFixed,
      @JsonKey(name: 'handling_fee_percent') this.handlingFeePercent,
      this.icon,
      @JsonKey(name: 'is_available') this.isAvailable = true,
      final Map<String, dynamic>? config,
      this.description,
      @JsonKey(name: 'min_amount') this.minAmount,
      @JsonKey(name: 'max_amount') this.maxAmount})
      : _config = config,
        super._();

  factory _$PaymentMethodModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentMethodModelImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey(name: 'payment')
  final String? paymentMethod;
// API字段为payment
  @override
  @JsonKey(name: 'handling_fee_fixed')
  final double? handlingFeeFixed;
  @override
  @JsonKey(name: 'handling_fee_percent')
  final double? handlingFeePercent;
  @override
  final String? icon;
  @override
  @JsonKey(name: 'is_available')
  final bool isAvailable;
  final Map<String, dynamic>? _config;
  @override
  Map<String, dynamic>? get config {
    final value = _config;
    if (value == null) return null;
    if (_config is EqualUnmodifiableMapView) return _config;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final String? description;
  @override
  @JsonKey(name: 'min_amount')
  final double? minAmount;
  @override
  @JsonKey(name: 'max_amount')
  final double? maxAmount;

  @override
  String toString() {
    return 'PaymentMethodModel(id: $id, name: $name, paymentMethod: $paymentMethod, handlingFeeFixed: $handlingFeeFixed, handlingFeePercent: $handlingFeePercent, icon: $icon, isAvailable: $isAvailable, config: $config, description: $description, minAmount: $minAmount, maxAmount: $maxAmount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentMethodModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.handlingFeeFixed, handlingFeeFixed) ||
                other.handlingFeeFixed == handlingFeeFixed) &&
            (identical(other.handlingFeePercent, handlingFeePercent) ||
                other.handlingFeePercent == handlingFeePercent) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.isAvailable, isAvailable) ||
                other.isAvailable == isAvailable) &&
            const DeepCollectionEquality().equals(other._config, _config) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.minAmount, minAmount) ||
                other.minAmount == minAmount) &&
            (identical(other.maxAmount, maxAmount) ||
                other.maxAmount == maxAmount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      paymentMethod,
      handlingFeeFixed,
      handlingFeePercent,
      icon,
      isAvailable,
      const DeepCollectionEquality().hash(_config),
      description,
      minAmount,
      maxAmount);

  /// Create a copy of PaymentMethodModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentMethodModelImplCopyWith<_$PaymentMethodModelImpl> get copyWith =>
      __$$PaymentMethodModelImplCopyWithImpl<_$PaymentMethodModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentMethodModelImplToJson(
      this,
    );
  }
}

abstract class _PaymentMethodModel extends PaymentMethodModel {
  const factory _PaymentMethodModel(
      {required final String id,
      required final String name,
      @JsonKey(name: 'payment') final String? paymentMethod,
      @JsonKey(name: 'handling_fee_fixed') final double? handlingFeeFixed,
      @JsonKey(name: 'handling_fee_percent') final double? handlingFeePercent,
      final String? icon,
      @JsonKey(name: 'is_available') final bool isAvailable,
      final Map<String, dynamic>? config,
      final String? description,
      @JsonKey(name: 'min_amount') final double? minAmount,
      @JsonKey(name: 'max_amount')
      final double? maxAmount}) = _$PaymentMethodModelImpl;
  const _PaymentMethodModel._() : super._();

  factory _PaymentMethodModel.fromJson(Map<String, dynamic> json) =
      _$PaymentMethodModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'payment')
  String? get paymentMethod; // API字段为payment
  @override
  @JsonKey(name: 'handling_fee_fixed')
  double? get handlingFeeFixed;
  @override
  @JsonKey(name: 'handling_fee_percent')
  double? get handlingFeePercent;
  @override
  String? get icon;
  @override
  @JsonKey(name: 'is_available')
  bool get isAvailable;
  @override
  Map<String, dynamic>? get config;
  @override
  String? get description;
  @override
  @JsonKey(name: 'min_amount')
  double? get minAmount;
  @override
  @JsonKey(name: 'max_amount')
  double? get maxAmount;

  /// Create a copy of PaymentMethodModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentMethodModelImplCopyWith<_$PaymentMethodModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PaymentResultModel _$PaymentResultModelFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'success':
      return PaymentResultSuccess.fromJson(json);
    case 'redirect':
      return PaymentResultRedirect.fromJson(json);
    case 'failed':
      return PaymentResultFailed.fromJson(json);
    case 'canceled':
      return PaymentResultCanceled.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'PaymentResultModel',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$PaymentResultModel {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String? transactionId, String? message, Map<String, dynamic>? extra)
        success,
    required TResult Function(
            String url, String? method, Map<String, String>? headers)
        redirect,
    required TResult Function(
            String message, String? errorCode, Map<String, dynamic>? extra)
        failed,
    required TResult Function(String? message) canceled,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? transactionId, String? message,
            Map<String, dynamic>? extra)?
        success,
    TResult? Function(String url, String? method, Map<String, String>? headers)?
        redirect,
    TResult? Function(
            String message, String? errorCode, Map<String, dynamic>? extra)?
        failed,
    TResult? Function(String? message)? canceled,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? transactionId, String? message,
            Map<String, dynamic>? extra)?
        success,
    TResult Function(String url, String? method, Map<String, String>? headers)?
        redirect,
    TResult Function(
            String message, String? errorCode, Map<String, dynamic>? extra)?
        failed,
    TResult Function(String? message)? canceled,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PaymentResultSuccess value) success,
    required TResult Function(PaymentResultRedirect value) redirect,
    required TResult Function(PaymentResultFailed value) failed,
    required TResult Function(PaymentResultCanceled value) canceled,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PaymentResultSuccess value)? success,
    TResult? Function(PaymentResultRedirect value)? redirect,
    TResult? Function(PaymentResultFailed value)? failed,
    TResult? Function(PaymentResultCanceled value)? canceled,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PaymentResultSuccess value)? success,
    TResult Function(PaymentResultRedirect value)? redirect,
    TResult Function(PaymentResultFailed value)? failed,
    TResult Function(PaymentResultCanceled value)? canceled,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this PaymentResultModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentResultModelCopyWith<$Res> {
  factory $PaymentResultModelCopyWith(
          PaymentResultModel value, $Res Function(PaymentResultModel) then) =
      _$PaymentResultModelCopyWithImpl<$Res, PaymentResultModel>;
}

/// @nodoc
class _$PaymentResultModelCopyWithImpl<$Res, $Val extends PaymentResultModel>
    implements $PaymentResultModelCopyWith<$Res> {
  _$PaymentResultModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentResultModel
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$PaymentResultSuccessImplCopyWith<$Res> {
  factory _$$PaymentResultSuccessImplCopyWith(_$PaymentResultSuccessImpl value,
          $Res Function(_$PaymentResultSuccessImpl) then) =
      __$$PaymentResultSuccessImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {String? transactionId, String? message, Map<String, dynamic>? extra});
}

/// @nodoc
class __$$PaymentResultSuccessImplCopyWithImpl<$Res>
    extends _$PaymentResultModelCopyWithImpl<$Res, _$PaymentResultSuccessImpl>
    implements _$$PaymentResultSuccessImplCopyWith<$Res> {
  __$$PaymentResultSuccessImplCopyWithImpl(_$PaymentResultSuccessImpl _value,
      $Res Function(_$PaymentResultSuccessImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentResultModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? transactionId = freezed,
    Object? message = freezed,
    Object? extra = freezed,
  }) {
    return _then(_$PaymentResultSuccessImpl(
      transactionId: freezed == transactionId
          ? _value.transactionId
          : transactionId // ignore: cast_nullable_to_non_nullable
              as String?,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      extra: freezed == extra
          ? _value._extra
          : extra // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaymentResultSuccessImpl implements PaymentResultSuccess {
  const _$PaymentResultSuccessImpl(
      {this.transactionId,
      this.message,
      final Map<String, dynamic>? extra,
      final String? $type})
      : _extra = extra,
        $type = $type ?? 'success';

  factory _$PaymentResultSuccessImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentResultSuccessImplFromJson(json);

  @override
  final String? transactionId;
  @override
  final String? message;
  final Map<String, dynamic>? _extra;
  @override
  Map<String, dynamic>? get extra {
    final value = _extra;
    if (value == null) return null;
    if (_extra is EqualUnmodifiableMapView) return _extra;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'PaymentResultModel.success(transactionId: $transactionId, message: $message, extra: $extra)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentResultSuccessImpl &&
            (identical(other.transactionId, transactionId) ||
                other.transactionId == transactionId) &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality().equals(other._extra, _extra));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, transactionId, message,
      const DeepCollectionEquality().hash(_extra));

  /// Create a copy of PaymentResultModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentResultSuccessImplCopyWith<_$PaymentResultSuccessImpl>
      get copyWith =>
          __$$PaymentResultSuccessImplCopyWithImpl<_$PaymentResultSuccessImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String? transactionId, String? message, Map<String, dynamic>? extra)
        success,
    required TResult Function(
            String url, String? method, Map<String, String>? headers)
        redirect,
    required TResult Function(
            String message, String? errorCode, Map<String, dynamic>? extra)
        failed,
    required TResult Function(String? message) canceled,
  }) {
    return success(transactionId, message, extra);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? transactionId, String? message,
            Map<String, dynamic>? extra)?
        success,
    TResult? Function(String url, String? method, Map<String, String>? headers)?
        redirect,
    TResult? Function(
            String message, String? errorCode, Map<String, dynamic>? extra)?
        failed,
    TResult? Function(String? message)? canceled,
  }) {
    return success?.call(transactionId, message, extra);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? transactionId, String? message,
            Map<String, dynamic>? extra)?
        success,
    TResult Function(String url, String? method, Map<String, String>? headers)?
        redirect,
    TResult Function(
            String message, String? errorCode, Map<String, dynamic>? extra)?
        failed,
    TResult Function(String? message)? canceled,
    required TResult orElse(),
  }) {
    if (success != null) {
      return success(transactionId, message, extra);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PaymentResultSuccess value) success,
    required TResult Function(PaymentResultRedirect value) redirect,
    required TResult Function(PaymentResultFailed value) failed,
    required TResult Function(PaymentResultCanceled value) canceled,
  }) {
    return success(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PaymentResultSuccess value)? success,
    TResult? Function(PaymentResultRedirect value)? redirect,
    TResult? Function(PaymentResultFailed value)? failed,
    TResult? Function(PaymentResultCanceled value)? canceled,
  }) {
    return success?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PaymentResultSuccess value)? success,
    TResult Function(PaymentResultRedirect value)? redirect,
    TResult Function(PaymentResultFailed value)? failed,
    TResult Function(PaymentResultCanceled value)? canceled,
    required TResult orElse(),
  }) {
    if (success != null) {
      return success(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentResultSuccessImplToJson(
      this,
    );
  }
}

abstract class PaymentResultSuccess implements PaymentResultModel {
  const factory PaymentResultSuccess(
      {final String? transactionId,
      final String? message,
      final Map<String, dynamic>? extra}) = _$PaymentResultSuccessImpl;

  factory PaymentResultSuccess.fromJson(Map<String, dynamic> json) =
      _$PaymentResultSuccessImpl.fromJson;

  String? get transactionId;
  String? get message;
  Map<String, dynamic>? get extra;

  /// Create a copy of PaymentResultModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentResultSuccessImplCopyWith<_$PaymentResultSuccessImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PaymentResultRedirectImplCopyWith<$Res> {
  factory _$$PaymentResultRedirectImplCopyWith(
          _$PaymentResultRedirectImpl value,
          $Res Function(_$PaymentResultRedirectImpl) then) =
      __$$PaymentResultRedirectImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String url, String? method, Map<String, String>? headers});
}

/// @nodoc
class __$$PaymentResultRedirectImplCopyWithImpl<$Res>
    extends _$PaymentResultModelCopyWithImpl<$Res, _$PaymentResultRedirectImpl>
    implements _$$PaymentResultRedirectImplCopyWith<$Res> {
  __$$PaymentResultRedirectImplCopyWithImpl(_$PaymentResultRedirectImpl _value,
      $Res Function(_$PaymentResultRedirectImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentResultModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? method = freezed,
    Object? headers = freezed,
  }) {
    return _then(_$PaymentResultRedirectImpl(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      method: freezed == method
          ? _value.method
          : method // ignore: cast_nullable_to_non_nullable
              as String?,
      headers: freezed == headers
          ? _value._headers
          : headers // ignore: cast_nullable_to_non_nullable
              as Map<String, String>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaymentResultRedirectImpl implements PaymentResultRedirect {
  const _$PaymentResultRedirectImpl(
      {required this.url,
      this.method,
      final Map<String, String>? headers,
      final String? $type})
      : _headers = headers,
        $type = $type ?? 'redirect';

  factory _$PaymentResultRedirectImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentResultRedirectImplFromJson(json);

  @override
  final String url;
  @override
  final String? method;
  final Map<String, String>? _headers;
  @override
  Map<String, String>? get headers {
    final value = _headers;
    if (value == null) return null;
    if (_headers is EqualUnmodifiableMapView) return _headers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'PaymentResultModel.redirect(url: $url, method: $method, headers: $headers)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentResultRedirectImpl &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.method, method) || other.method == method) &&
            const DeepCollectionEquality().equals(other._headers, _headers));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, url, method, const DeepCollectionEquality().hash(_headers));

  /// Create a copy of PaymentResultModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentResultRedirectImplCopyWith<_$PaymentResultRedirectImpl>
      get copyWith => __$$PaymentResultRedirectImplCopyWithImpl<
          _$PaymentResultRedirectImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String? transactionId, String? message, Map<String, dynamic>? extra)
        success,
    required TResult Function(
            String url, String? method, Map<String, String>? headers)
        redirect,
    required TResult Function(
            String message, String? errorCode, Map<String, dynamic>? extra)
        failed,
    required TResult Function(String? message) canceled,
  }) {
    return redirect(url, method, headers);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? transactionId, String? message,
            Map<String, dynamic>? extra)?
        success,
    TResult? Function(String url, String? method, Map<String, String>? headers)?
        redirect,
    TResult? Function(
            String message, String? errorCode, Map<String, dynamic>? extra)?
        failed,
    TResult? Function(String? message)? canceled,
  }) {
    return redirect?.call(url, method, headers);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? transactionId, String? message,
            Map<String, dynamic>? extra)?
        success,
    TResult Function(String url, String? method, Map<String, String>? headers)?
        redirect,
    TResult Function(
            String message, String? errorCode, Map<String, dynamic>? extra)?
        failed,
    TResult Function(String? message)? canceled,
    required TResult orElse(),
  }) {
    if (redirect != null) {
      return redirect(url, method, headers);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PaymentResultSuccess value) success,
    required TResult Function(PaymentResultRedirect value) redirect,
    required TResult Function(PaymentResultFailed value) failed,
    required TResult Function(PaymentResultCanceled value) canceled,
  }) {
    return redirect(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PaymentResultSuccess value)? success,
    TResult? Function(PaymentResultRedirect value)? redirect,
    TResult? Function(PaymentResultFailed value)? failed,
    TResult? Function(PaymentResultCanceled value)? canceled,
  }) {
    return redirect?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PaymentResultSuccess value)? success,
    TResult Function(PaymentResultRedirect value)? redirect,
    TResult Function(PaymentResultFailed value)? failed,
    TResult Function(PaymentResultCanceled value)? canceled,
    required TResult orElse(),
  }) {
    if (redirect != null) {
      return redirect(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentResultRedirectImplToJson(
      this,
    );
  }
}

abstract class PaymentResultRedirect implements PaymentResultModel {
  const factory PaymentResultRedirect(
      {required final String url,
      final String? method,
      final Map<String, String>? headers}) = _$PaymentResultRedirectImpl;

  factory PaymentResultRedirect.fromJson(Map<String, dynamic> json) =
      _$PaymentResultRedirectImpl.fromJson;

  String get url;
  String? get method;
  Map<String, String>? get headers;

  /// Create a copy of PaymentResultModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentResultRedirectImplCopyWith<_$PaymentResultRedirectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PaymentResultFailedImplCopyWith<$Res> {
  factory _$$PaymentResultFailedImplCopyWith(_$PaymentResultFailedImpl value,
          $Res Function(_$PaymentResultFailedImpl) then) =
      __$$PaymentResultFailedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message, String? errorCode, Map<String, dynamic>? extra});
}

/// @nodoc
class __$$PaymentResultFailedImplCopyWithImpl<$Res>
    extends _$PaymentResultModelCopyWithImpl<$Res, _$PaymentResultFailedImpl>
    implements _$$PaymentResultFailedImplCopyWith<$Res> {
  __$$PaymentResultFailedImplCopyWithImpl(_$PaymentResultFailedImpl _value,
      $Res Function(_$PaymentResultFailedImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentResultModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? errorCode = freezed,
    Object? extra = freezed,
  }) {
    return _then(_$PaymentResultFailedImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      errorCode: freezed == errorCode
          ? _value.errorCode
          : errorCode // ignore: cast_nullable_to_non_nullable
              as String?,
      extra: freezed == extra
          ? _value._extra
          : extra // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaymentResultFailedImpl implements PaymentResultFailed {
  const _$PaymentResultFailedImpl(
      {required this.message,
      this.errorCode,
      final Map<String, dynamic>? extra,
      final String? $type})
      : _extra = extra,
        $type = $type ?? 'failed';

  factory _$PaymentResultFailedImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentResultFailedImplFromJson(json);

  @override
  final String message;
  @override
  final String? errorCode;
  final Map<String, dynamic>? _extra;
  @override
  Map<String, dynamic>? get extra {
    final value = _extra;
    if (value == null) return null;
    if (_extra is EqualUnmodifiableMapView) return _extra;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'PaymentResultModel.failed(message: $message, errorCode: $errorCode, extra: $extra)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentResultFailedImpl &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.errorCode, errorCode) ||
                other.errorCode == errorCode) &&
            const DeepCollectionEquality().equals(other._extra, _extra));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, message, errorCode,
      const DeepCollectionEquality().hash(_extra));

  /// Create a copy of PaymentResultModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentResultFailedImplCopyWith<_$PaymentResultFailedImpl> get copyWith =>
      __$$PaymentResultFailedImplCopyWithImpl<_$PaymentResultFailedImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String? transactionId, String? message, Map<String, dynamic>? extra)
        success,
    required TResult Function(
            String url, String? method, Map<String, String>? headers)
        redirect,
    required TResult Function(
            String message, String? errorCode, Map<String, dynamic>? extra)
        failed,
    required TResult Function(String? message) canceled,
  }) {
    return failed(message, errorCode, extra);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? transactionId, String? message,
            Map<String, dynamic>? extra)?
        success,
    TResult? Function(String url, String? method, Map<String, String>? headers)?
        redirect,
    TResult? Function(
            String message, String? errorCode, Map<String, dynamic>? extra)?
        failed,
    TResult? Function(String? message)? canceled,
  }) {
    return failed?.call(message, errorCode, extra);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? transactionId, String? message,
            Map<String, dynamic>? extra)?
        success,
    TResult Function(String url, String? method, Map<String, String>? headers)?
        redirect,
    TResult Function(
            String message, String? errorCode, Map<String, dynamic>? extra)?
        failed,
    TResult Function(String? message)? canceled,
    required TResult orElse(),
  }) {
    if (failed != null) {
      return failed(message, errorCode, extra);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PaymentResultSuccess value) success,
    required TResult Function(PaymentResultRedirect value) redirect,
    required TResult Function(PaymentResultFailed value) failed,
    required TResult Function(PaymentResultCanceled value) canceled,
  }) {
    return failed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PaymentResultSuccess value)? success,
    TResult? Function(PaymentResultRedirect value)? redirect,
    TResult? Function(PaymentResultFailed value)? failed,
    TResult? Function(PaymentResultCanceled value)? canceled,
  }) {
    return failed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PaymentResultSuccess value)? success,
    TResult Function(PaymentResultRedirect value)? redirect,
    TResult Function(PaymentResultFailed value)? failed,
    TResult Function(PaymentResultCanceled value)? canceled,
    required TResult orElse(),
  }) {
    if (failed != null) {
      return failed(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentResultFailedImplToJson(
      this,
    );
  }
}

abstract class PaymentResultFailed implements PaymentResultModel {
  const factory PaymentResultFailed(
      {required final String message,
      final String? errorCode,
      final Map<String, dynamic>? extra}) = _$PaymentResultFailedImpl;

  factory PaymentResultFailed.fromJson(Map<String, dynamic> json) =
      _$PaymentResultFailedImpl.fromJson;

  String get message;
  String? get errorCode;
  Map<String, dynamic>? get extra;

  /// Create a copy of PaymentResultModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentResultFailedImplCopyWith<_$PaymentResultFailedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PaymentResultCanceledImplCopyWith<$Res> {
  factory _$$PaymentResultCanceledImplCopyWith(
          _$PaymentResultCanceledImpl value,
          $Res Function(_$PaymentResultCanceledImpl) then) =
      __$$PaymentResultCanceledImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$PaymentResultCanceledImplCopyWithImpl<$Res>
    extends _$PaymentResultModelCopyWithImpl<$Res, _$PaymentResultCanceledImpl>
    implements _$$PaymentResultCanceledImplCopyWith<$Res> {
  __$$PaymentResultCanceledImplCopyWithImpl(_$PaymentResultCanceledImpl _value,
      $Res Function(_$PaymentResultCanceledImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentResultModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$PaymentResultCanceledImpl(
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaymentResultCanceledImpl implements PaymentResultCanceled {
  const _$PaymentResultCanceledImpl({this.message, final String? $type})
      : $type = $type ?? 'canceled';

  factory _$PaymentResultCanceledImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentResultCanceledImplFromJson(json);

  @override
  final String? message;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'PaymentResultModel.canceled(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentResultCanceledImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of PaymentResultModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentResultCanceledImplCopyWith<_$PaymentResultCanceledImpl>
      get copyWith => __$$PaymentResultCanceledImplCopyWithImpl<
          _$PaymentResultCanceledImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String? transactionId, String? message, Map<String, dynamic>? extra)
        success,
    required TResult Function(
            String url, String? method, Map<String, String>? headers)
        redirect,
    required TResult Function(
            String message, String? errorCode, Map<String, dynamic>? extra)
        failed,
    required TResult Function(String? message) canceled,
  }) {
    return canceled(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String? transactionId, String? message,
            Map<String, dynamic>? extra)?
        success,
    TResult? Function(String url, String? method, Map<String, String>? headers)?
        redirect,
    TResult? Function(
            String message, String? errorCode, Map<String, dynamic>? extra)?
        failed,
    TResult? Function(String? message)? canceled,
  }) {
    return canceled?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String? transactionId, String? message,
            Map<String, dynamic>? extra)?
        success,
    TResult Function(String url, String? method, Map<String, String>? headers)?
        redirect,
    TResult Function(
            String message, String? errorCode, Map<String, dynamic>? extra)?
        failed,
    TResult Function(String? message)? canceled,
    required TResult orElse(),
  }) {
    if (canceled != null) {
      return canceled(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PaymentResultSuccess value) success,
    required TResult Function(PaymentResultRedirect value) redirect,
    required TResult Function(PaymentResultFailed value) failed,
    required TResult Function(PaymentResultCanceled value) canceled,
  }) {
    return canceled(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PaymentResultSuccess value)? success,
    TResult? Function(PaymentResultRedirect value)? redirect,
    TResult? Function(PaymentResultFailed value)? failed,
    TResult? Function(PaymentResultCanceled value)? canceled,
  }) {
    return canceled?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PaymentResultSuccess value)? success,
    TResult Function(PaymentResultRedirect value)? redirect,
    TResult Function(PaymentResultFailed value)? failed,
    TResult Function(PaymentResultCanceled value)? canceled,
    required TResult orElse(),
  }) {
    if (canceled != null) {
      return canceled(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentResultCanceledImplToJson(
      this,
    );
  }
}

abstract class PaymentResultCanceled implements PaymentResultModel {
  const factory PaymentResultCanceled({final String? message}) =
      _$PaymentResultCanceledImpl;

  factory PaymentResultCanceled.fromJson(Map<String, dynamic> json) =
      _$PaymentResultCanceledImpl.fromJson;

  String? get message;

  /// Create a copy of PaymentResultModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentResultCanceledImplCopyWith<_$PaymentResultCanceledImpl>
      get copyWith => throw _privateConstructorUsedError;
}
