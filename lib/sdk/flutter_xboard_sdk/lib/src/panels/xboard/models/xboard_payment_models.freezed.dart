// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'xboard_payment_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PaymentStatusResult _$PaymentStatusResultFromJson(Map<String, dynamic> json) {
  return _PaymentStatusResult.fromJson(json);
}

/// @nodoc
mixin _$PaymentStatusResult {
  bool get isSuccess => throw _privateConstructorUsedError;
  bool get isCanceled => throw _privateConstructorUsedError;
  bool get isPending => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;

  /// Serializes this PaymentStatusResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PaymentStatusResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaymentStatusResultCopyWith<PaymentStatusResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentStatusResultCopyWith<$Res> {
  factory $PaymentStatusResultCopyWith(
          PaymentStatusResult value, $Res Function(PaymentStatusResult) then) =
      _$PaymentStatusResultCopyWithImpl<$Res, PaymentStatusResult>;
  @useResult
  $Res call({bool isSuccess, bool isCanceled, bool isPending, String? message});
}

/// @nodoc
class _$PaymentStatusResultCopyWithImpl<$Res, $Val extends PaymentStatusResult>
    implements $PaymentStatusResultCopyWith<$Res> {
  _$PaymentStatusResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentStatusResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isSuccess = null,
    Object? isCanceled = null,
    Object? isPending = null,
    Object? message = freezed,
  }) {
    return _then(_value.copyWith(
      isSuccess: null == isSuccess
          ? _value.isSuccess
          : isSuccess // ignore: cast_nullable_to_non_nullable
              as bool,
      isCanceled: null == isCanceled
          ? _value.isCanceled
          : isCanceled // ignore: cast_nullable_to_non_nullable
              as bool,
      isPending: null == isPending
          ? _value.isPending
          : isPending // ignore: cast_nullable_to_non_nullable
              as bool,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PaymentStatusResultImplCopyWith<$Res>
    implements $PaymentStatusResultCopyWith<$Res> {
  factory _$$PaymentStatusResultImplCopyWith(_$PaymentStatusResultImpl value,
          $Res Function(_$PaymentStatusResultImpl) then) =
      __$$PaymentStatusResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool isSuccess, bool isCanceled, bool isPending, String? message});
}

/// @nodoc
class __$$PaymentStatusResultImplCopyWithImpl<$Res>
    extends _$PaymentStatusResultCopyWithImpl<$Res, _$PaymentStatusResultImpl>
    implements _$$PaymentStatusResultImplCopyWith<$Res> {
  __$$PaymentStatusResultImplCopyWithImpl(_$PaymentStatusResultImpl _value,
      $Res Function(_$PaymentStatusResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentStatusResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isSuccess = null,
    Object? isCanceled = null,
    Object? isPending = null,
    Object? message = freezed,
  }) {
    return _then(_$PaymentStatusResultImpl(
      isSuccess: null == isSuccess
          ? _value.isSuccess
          : isSuccess // ignore: cast_nullable_to_non_nullable
              as bool,
      isCanceled: null == isCanceled
          ? _value.isCanceled
          : isCanceled // ignore: cast_nullable_to_non_nullable
              as bool,
      isPending: null == isPending
          ? _value.isPending
          : isPending // ignore: cast_nullable_to_non_nullable
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
class _$PaymentStatusResultImpl implements _PaymentStatusResult {
  const _$PaymentStatusResultImpl(
      {required this.isSuccess,
      required this.isCanceled,
      required this.isPending,
      this.message});

  factory _$PaymentStatusResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentStatusResultImplFromJson(json);

  @override
  final bool isSuccess;
  @override
  final bool isCanceled;
  @override
  final bool isPending;
  @override
  final String? message;

  @override
  String toString() {
    return 'PaymentStatusResult(isSuccess: $isSuccess, isCanceled: $isCanceled, isPending: $isPending, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentStatusResultImpl &&
            (identical(other.isSuccess, isSuccess) ||
                other.isSuccess == isSuccess) &&
            (identical(other.isCanceled, isCanceled) ||
                other.isCanceled == isCanceled) &&
            (identical(other.isPending, isPending) ||
                other.isPending == isPending) &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, isSuccess, isCanceled, isPending, message);

  /// Create a copy of PaymentStatusResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentStatusResultImplCopyWith<_$PaymentStatusResultImpl> get copyWith =>
      __$$PaymentStatusResultImplCopyWithImpl<_$PaymentStatusResultImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentStatusResultImplToJson(
      this,
    );
  }
}

abstract class _PaymentStatusResult implements PaymentStatusResult {
  const factory _PaymentStatusResult(
      {required final bool isSuccess,
      required final bool isCanceled,
      required final bool isPending,
      final String? message}) = _$PaymentStatusResultImpl;

  factory _PaymentStatusResult.fromJson(Map<String, dynamic> json) =
      _$PaymentStatusResultImpl.fromJson;

  @override
  bool get isSuccess;
  @override
  bool get isCanceled;
  @override
  bool get isPending;
  @override
  String? get message;

  /// Create a copy of PaymentStatusResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentStatusResultImplCopyWith<_$PaymentStatusResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PaymentMethodInfo {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'handling_fee_percent')
  double get feePercent => throw _privateConstructorUsedError;
  String? get icon => throw _privateConstructorUsedError;
  bool get isAvailable => throw _privateConstructorUsedError;
  Map<String, dynamic>? get config => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  double? get minAmount => throw _privateConstructorUsedError;
  double? get maxAmount => throw _privateConstructorUsedError;

  /// Create a copy of PaymentMethodInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaymentMethodInfoCopyWith<PaymentMethodInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentMethodInfoCopyWith<$Res> {
  factory $PaymentMethodInfoCopyWith(
          PaymentMethodInfo value, $Res Function(PaymentMethodInfo) then) =
      _$PaymentMethodInfoCopyWithImpl<$Res, PaymentMethodInfo>;
  @useResult
  $Res call(
      {String id,
      String name,
      @JsonKey(name: 'handling_fee_percent') double feePercent,
      String? icon,
      bool isAvailable,
      Map<String, dynamic>? config,
      String? description,
      double? minAmount,
      double? maxAmount});
}

/// @nodoc
class _$PaymentMethodInfoCopyWithImpl<$Res, $Val extends PaymentMethodInfo>
    implements $PaymentMethodInfoCopyWith<$Res> {
  _$PaymentMethodInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentMethodInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? feePercent = null,
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
      feePercent: null == feePercent
          ? _value.feePercent
          : feePercent // ignore: cast_nullable_to_non_nullable
              as double,
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
abstract class _$$PaymentMethodInfoImplCopyWith<$Res>
    implements $PaymentMethodInfoCopyWith<$Res> {
  factory _$$PaymentMethodInfoImplCopyWith(_$PaymentMethodInfoImpl value,
          $Res Function(_$PaymentMethodInfoImpl) then) =
      __$$PaymentMethodInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      @JsonKey(name: 'handling_fee_percent') double feePercent,
      String? icon,
      bool isAvailable,
      Map<String, dynamic>? config,
      String? description,
      double? minAmount,
      double? maxAmount});
}

/// @nodoc
class __$$PaymentMethodInfoImplCopyWithImpl<$Res>
    extends _$PaymentMethodInfoCopyWithImpl<$Res, _$PaymentMethodInfoImpl>
    implements _$$PaymentMethodInfoImplCopyWith<$Res> {
  __$$PaymentMethodInfoImplCopyWithImpl(_$PaymentMethodInfoImpl _value,
      $Res Function(_$PaymentMethodInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentMethodInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? feePercent = null,
    Object? icon = freezed,
    Object? isAvailable = null,
    Object? config = freezed,
    Object? description = freezed,
    Object? minAmount = freezed,
    Object? maxAmount = freezed,
  }) {
    return _then(_$PaymentMethodInfoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      feePercent: null == feePercent
          ? _value.feePercent
          : feePercent // ignore: cast_nullable_to_non_nullable
              as double,
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

class _$PaymentMethodInfoImpl extends _PaymentMethodInfo {
  const _$PaymentMethodInfoImpl(
      {required this.id,
      required this.name,
      @JsonKey(name: 'handling_fee_percent') required this.feePercent,
      this.icon,
      this.isAvailable = true,
      final Map<String, dynamic>? config,
      this.description,
      this.minAmount,
      this.maxAmount})
      : _config = config,
        super._();

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey(name: 'handling_fee_percent')
  final double feePercent;
  @override
  final String? icon;
  @override
  @JsonKey()
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
  final double? minAmount;
  @override
  final double? maxAmount;

  @override
  String toString() {
    return 'PaymentMethodInfo(id: $id, name: $name, feePercent: $feePercent, icon: $icon, isAvailable: $isAvailable, config: $config, description: $description, minAmount: $minAmount, maxAmount: $maxAmount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentMethodInfoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.feePercent, feePercent) ||
                other.feePercent == feePercent) &&
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

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      feePercent,
      icon,
      isAvailable,
      const DeepCollectionEquality().hash(_config),
      description,
      minAmount,
      maxAmount);

  /// Create a copy of PaymentMethodInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentMethodInfoImplCopyWith<_$PaymentMethodInfoImpl> get copyWith =>
      __$$PaymentMethodInfoImplCopyWithImpl<_$PaymentMethodInfoImpl>(
          this, _$identity);
}

abstract class _PaymentMethodInfo extends PaymentMethodInfo {
  const factory _PaymentMethodInfo(
      {required final String id,
      required final String name,
      @JsonKey(name: 'handling_fee_percent') required final double feePercent,
      final String? icon,
      final bool isAvailable,
      final Map<String, dynamic>? config,
      final String? description,
      final double? minAmount,
      final double? maxAmount}) = _$PaymentMethodInfoImpl;
  const _PaymentMethodInfo._() : super._();

  @override
  String get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'handling_fee_percent')
  double get feePercent;
  @override
  String? get icon;
  @override
  bool get isAvailable;
  @override
  Map<String, dynamic>? get config;
  @override
  String? get description;
  @override
  double? get minAmount;
  @override
  double? get maxAmount;

  /// Create a copy of PaymentMethodInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentMethodInfoImplCopyWith<_$PaymentMethodInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PaymentOrderInfo _$PaymentOrderInfoFromJson(Map<String, dynamic> json) {
  return _PaymentOrderInfo.fromJson(json);
}

/// @nodoc
mixin _$PaymentOrderInfo {
  String get tradeNo => throw _privateConstructorUsedError;
  double get originalAmount => throw _privateConstructorUsedError;
  double get finalAmount => throw _privateConstructorUsedError;
  String? get couponCode => throw _privateConstructorUsedError;
  double? get discountAmount => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  DateTime? get expireTime => throw _privateConstructorUsedError;

  /// Serializes this PaymentOrderInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PaymentOrderInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaymentOrderInfoCopyWith<PaymentOrderInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentOrderInfoCopyWith<$Res> {
  factory $PaymentOrderInfoCopyWith(
          PaymentOrderInfo value, $Res Function(PaymentOrderInfo) then) =
      _$PaymentOrderInfoCopyWithImpl<$Res, PaymentOrderInfo>;
  @useResult
  $Res call(
      {String tradeNo,
      double originalAmount,
      double finalAmount,
      String? couponCode,
      double? discountAmount,
      String currency,
      DateTime? expireTime});
}

/// @nodoc
class _$PaymentOrderInfoCopyWithImpl<$Res, $Val extends PaymentOrderInfo>
    implements $PaymentOrderInfoCopyWith<$Res> {
  _$PaymentOrderInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentOrderInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tradeNo = null,
    Object? originalAmount = null,
    Object? finalAmount = null,
    Object? couponCode = freezed,
    Object? discountAmount = freezed,
    Object? currency = null,
    Object? expireTime = freezed,
  }) {
    return _then(_value.copyWith(
      tradeNo: null == tradeNo
          ? _value.tradeNo
          : tradeNo // ignore: cast_nullable_to_non_nullable
              as String,
      originalAmount: null == originalAmount
          ? _value.originalAmount
          : originalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      finalAmount: null == finalAmount
          ? _value.finalAmount
          : finalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      couponCode: freezed == couponCode
          ? _value.couponCode
          : couponCode // ignore: cast_nullable_to_non_nullable
              as String?,
      discountAmount: freezed == discountAmount
          ? _value.discountAmount
          : discountAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      expireTime: freezed == expireTime
          ? _value.expireTime
          : expireTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PaymentOrderInfoImplCopyWith<$Res>
    implements $PaymentOrderInfoCopyWith<$Res> {
  factory _$$PaymentOrderInfoImplCopyWith(_$PaymentOrderInfoImpl value,
          $Res Function(_$PaymentOrderInfoImpl) then) =
      __$$PaymentOrderInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String tradeNo,
      double originalAmount,
      double finalAmount,
      String? couponCode,
      double? discountAmount,
      String currency,
      DateTime? expireTime});
}

/// @nodoc
class __$$PaymentOrderInfoImplCopyWithImpl<$Res>
    extends _$PaymentOrderInfoCopyWithImpl<$Res, _$PaymentOrderInfoImpl>
    implements _$$PaymentOrderInfoImplCopyWith<$Res> {
  __$$PaymentOrderInfoImplCopyWithImpl(_$PaymentOrderInfoImpl _value,
      $Res Function(_$PaymentOrderInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentOrderInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tradeNo = null,
    Object? originalAmount = null,
    Object? finalAmount = null,
    Object? couponCode = freezed,
    Object? discountAmount = freezed,
    Object? currency = null,
    Object? expireTime = freezed,
  }) {
    return _then(_$PaymentOrderInfoImpl(
      tradeNo: null == tradeNo
          ? _value.tradeNo
          : tradeNo // ignore: cast_nullable_to_non_nullable
              as String,
      originalAmount: null == originalAmount
          ? _value.originalAmount
          : originalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      finalAmount: null == finalAmount
          ? _value.finalAmount
          : finalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      couponCode: freezed == couponCode
          ? _value.couponCode
          : couponCode // ignore: cast_nullable_to_non_nullable
              as String?,
      discountAmount: freezed == discountAmount
          ? _value.discountAmount
          : discountAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      expireTime: freezed == expireTime
          ? _value.expireTime
          : expireTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaymentOrderInfoImpl extends _PaymentOrderInfo {
  const _$PaymentOrderInfoImpl(
      {required this.tradeNo,
      required this.originalAmount,
      this.finalAmount = 0.0,
      this.couponCode,
      this.discountAmount,
      this.currency = 'CNY',
      this.expireTime})
      : super._();

  factory _$PaymentOrderInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentOrderInfoImplFromJson(json);

  @override
  final String tradeNo;
  @override
  final double originalAmount;
  @override
  @JsonKey()
  final double finalAmount;
  @override
  final String? couponCode;
  @override
  final double? discountAmount;
  @override
  @JsonKey()
  final String currency;
  @override
  final DateTime? expireTime;

  @override
  String toString() {
    return 'PaymentOrderInfo(tradeNo: $tradeNo, originalAmount: $originalAmount, finalAmount: $finalAmount, couponCode: $couponCode, discountAmount: $discountAmount, currency: $currency, expireTime: $expireTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentOrderInfoImpl &&
            (identical(other.tradeNo, tradeNo) || other.tradeNo == tradeNo) &&
            (identical(other.originalAmount, originalAmount) ||
                other.originalAmount == originalAmount) &&
            (identical(other.finalAmount, finalAmount) ||
                other.finalAmount == finalAmount) &&
            (identical(other.couponCode, couponCode) ||
                other.couponCode == couponCode) &&
            (identical(other.discountAmount, discountAmount) ||
                other.discountAmount == discountAmount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.expireTime, expireTime) ||
                other.expireTime == expireTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, tradeNo, originalAmount,
      finalAmount, couponCode, discountAmount, currency, expireTime);

  /// Create a copy of PaymentOrderInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentOrderInfoImplCopyWith<_$PaymentOrderInfoImpl> get copyWith =>
      __$$PaymentOrderInfoImplCopyWithImpl<_$PaymentOrderInfoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentOrderInfoImplToJson(
      this,
    );
  }
}

abstract class _PaymentOrderInfo extends PaymentOrderInfo {
  const factory _PaymentOrderInfo(
      {required final String tradeNo,
      required final double originalAmount,
      final double finalAmount,
      final String? couponCode,
      final double? discountAmount,
      final String currency,
      final DateTime? expireTime}) = _$PaymentOrderInfoImpl;
  const _PaymentOrderInfo._() : super._();

  factory _PaymentOrderInfo.fromJson(Map<String, dynamic> json) =
      _$PaymentOrderInfoImpl.fromJson;

  @override
  String get tradeNo;
  @override
  double get originalAmount;
  @override
  double get finalAmount;
  @override
  String? get couponCode;
  @override
  double? get discountAmount;
  @override
  String get currency;
  @override
  DateTime? get expireTime;

  /// Create a copy of PaymentOrderInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentOrderInfoImplCopyWith<_$PaymentOrderInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PaymentResult _$PaymentResultFromJson(Map<String, dynamic> json) {
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
      throw CheckedFromJsonException(json, 'runtimeType', 'PaymentResult',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$PaymentResult {
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

  /// Serializes this PaymentResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentResultCopyWith<$Res> {
  factory $PaymentResultCopyWith(
          PaymentResult value, $Res Function(PaymentResult) then) =
      _$PaymentResultCopyWithImpl<$Res, PaymentResult>;
}

/// @nodoc
class _$PaymentResultCopyWithImpl<$Res, $Val extends PaymentResult>
    implements $PaymentResultCopyWith<$Res> {
  _$PaymentResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentResult
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
    extends _$PaymentResultCopyWithImpl<$Res, _$PaymentResultSuccessImpl>
    implements _$$PaymentResultSuccessImplCopyWith<$Res> {
  __$$PaymentResultSuccessImplCopyWithImpl(_$PaymentResultSuccessImpl _value,
      $Res Function(_$PaymentResultSuccessImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentResult
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
    return 'PaymentResult.success(transactionId: $transactionId, message: $message, extra: $extra)';
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

  /// Create a copy of PaymentResult
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

abstract class PaymentResultSuccess implements PaymentResult {
  const factory PaymentResultSuccess(
      {final String? transactionId,
      final String? message,
      final Map<String, dynamic>? extra}) = _$PaymentResultSuccessImpl;

  factory PaymentResultSuccess.fromJson(Map<String, dynamic> json) =
      _$PaymentResultSuccessImpl.fromJson;

  String? get transactionId;
  String? get message;
  Map<String, dynamic>? get extra;

  /// Create a copy of PaymentResult
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
    extends _$PaymentResultCopyWithImpl<$Res, _$PaymentResultRedirectImpl>
    implements _$$PaymentResultRedirectImplCopyWith<$Res> {
  __$$PaymentResultRedirectImplCopyWithImpl(_$PaymentResultRedirectImpl _value,
      $Res Function(_$PaymentResultRedirectImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentResult
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
    return 'PaymentResult.redirect(url: $url, method: $method, headers: $headers)';
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

  /// Create a copy of PaymentResult
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

abstract class PaymentResultRedirect implements PaymentResult {
  const factory PaymentResultRedirect(
      {required final String url,
      final String? method,
      final Map<String, String>? headers}) = _$PaymentResultRedirectImpl;

  factory PaymentResultRedirect.fromJson(Map<String, dynamic> json) =
      _$PaymentResultRedirectImpl.fromJson;

  String get url;
  String? get method;
  Map<String, String>? get headers;

  /// Create a copy of PaymentResult
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
    extends _$PaymentResultCopyWithImpl<$Res, _$PaymentResultFailedImpl>
    implements _$$PaymentResultFailedImplCopyWith<$Res> {
  __$$PaymentResultFailedImplCopyWithImpl(_$PaymentResultFailedImpl _value,
      $Res Function(_$PaymentResultFailedImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentResult
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
    return 'PaymentResult.failed(message: $message, errorCode: $errorCode, extra: $extra)';
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

  /// Create a copy of PaymentResult
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

abstract class PaymentResultFailed implements PaymentResult {
  const factory PaymentResultFailed(
      {required final String message,
      final String? errorCode,
      final Map<String, dynamic>? extra}) = _$PaymentResultFailedImpl;

  factory PaymentResultFailed.fromJson(Map<String, dynamic> json) =
      _$PaymentResultFailedImpl.fromJson;

  String get message;
  String? get errorCode;
  Map<String, dynamic>? get extra;

  /// Create a copy of PaymentResult
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
    extends _$PaymentResultCopyWithImpl<$Res, _$PaymentResultCanceledImpl>
    implements _$$PaymentResultCanceledImplCopyWith<$Res> {
  __$$PaymentResultCanceledImplCopyWithImpl(_$PaymentResultCanceledImpl _value,
      $Res Function(_$PaymentResultCanceledImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentResult
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
    return 'PaymentResult.canceled(message: $message)';
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

  /// Create a copy of PaymentResult
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

abstract class PaymentResultCanceled implements PaymentResult {
  const factory PaymentResultCanceled({final String? message}) =
      _$PaymentResultCanceledImpl;

  factory PaymentResultCanceled.fromJson(Map<String, dynamic> json) =
      _$PaymentResultCanceledImpl.fromJson;

  String? get message;

  /// Create a copy of PaymentResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentResultCanceledImplCopyWith<_$PaymentResultCanceledImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PaymentError {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noToken,
    required TResult Function(String? message) networkError,
    required TResult Function(String? message) invalidResponse,
    required TResult Function(String? message) preCheckFailed,
    required TResult Function(String? url) cannotLaunchUrl,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) invalidAmount,
    required TResult Function(String? message) paymentMethodUnavailable,
    required TResult Function(String message) unknownError,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noToken,
    TResult? Function(String? message)? networkError,
    TResult? Function(String? message)? invalidResponse,
    TResult? Function(String? message)? preCheckFailed,
    TResult? Function(String? url)? cannotLaunchUrl,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? invalidAmount,
    TResult? Function(String? message)? paymentMethodUnavailable,
    TResult? Function(String message)? unknownError,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noToken,
    TResult Function(String? message)? networkError,
    TResult Function(String? message)? invalidResponse,
    TResult Function(String? message)? preCheckFailed,
    TResult Function(String? url)? cannotLaunchUrl,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? invalidAmount,
    TResult Function(String? message)? paymentMethodUnavailable,
    TResult Function(String message)? unknownError,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NoTokenError value) noToken,
    required TResult Function(NetworkError value) networkError,
    required TResult Function(InvalidResponseError value) invalidResponse,
    required TResult Function(PreCheckError value) preCheckFailed,
    required TResult Function(UrlLaunchError value) cannotLaunchUrl,
    required TResult Function(PaymentTimeoutError value) timeout,
    required TResult Function(InvalidAmountError value) invalidAmount,
    required TResult Function(PaymentMethodUnavailableError value)
        paymentMethodUnavailable,
    required TResult Function(UnknownError value) unknownError,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NoTokenError value)? noToken,
    TResult? Function(NetworkError value)? networkError,
    TResult? Function(InvalidResponseError value)? invalidResponse,
    TResult? Function(PreCheckError value)? preCheckFailed,
    TResult? Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult? Function(PaymentTimeoutError value)? timeout,
    TResult? Function(InvalidAmountError value)? invalidAmount,
    TResult? Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult? Function(UnknownError value)? unknownError,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NoTokenError value)? noToken,
    TResult Function(NetworkError value)? networkError,
    TResult Function(InvalidResponseError value)? invalidResponse,
    TResult Function(PreCheckError value)? preCheckFailed,
    TResult Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult Function(PaymentTimeoutError value)? timeout,
    TResult Function(InvalidAmountError value)? invalidAmount,
    TResult Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult Function(UnknownError value)? unknownError,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentErrorCopyWith<$Res> {
  factory $PaymentErrorCopyWith(
          PaymentError value, $Res Function(PaymentError) then) =
      _$PaymentErrorCopyWithImpl<$Res, PaymentError>;
}

/// @nodoc
class _$PaymentErrorCopyWithImpl<$Res, $Val extends PaymentError>
    implements $PaymentErrorCopyWith<$Res> {
  _$PaymentErrorCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$NoTokenErrorImplCopyWith<$Res> {
  factory _$$NoTokenErrorImplCopyWith(
          _$NoTokenErrorImpl value, $Res Function(_$NoTokenErrorImpl) then) =
      __$$NoTokenErrorImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$NoTokenErrorImplCopyWithImpl<$Res>
    extends _$PaymentErrorCopyWithImpl<$Res, _$NoTokenErrorImpl>
    implements _$$NoTokenErrorImplCopyWith<$Res> {
  __$$NoTokenErrorImplCopyWithImpl(
      _$NoTokenErrorImpl _value, $Res Function(_$NoTokenErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$NoTokenErrorImpl extends NoTokenError {
  const _$NoTokenErrorImpl() : super._();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$NoTokenErrorImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noToken,
    required TResult Function(String? message) networkError,
    required TResult Function(String? message) invalidResponse,
    required TResult Function(String? message) preCheckFailed,
    required TResult Function(String? url) cannotLaunchUrl,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) invalidAmount,
    required TResult Function(String? message) paymentMethodUnavailable,
    required TResult Function(String message) unknownError,
  }) {
    return noToken();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noToken,
    TResult? Function(String? message)? networkError,
    TResult? Function(String? message)? invalidResponse,
    TResult? Function(String? message)? preCheckFailed,
    TResult? Function(String? url)? cannotLaunchUrl,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? invalidAmount,
    TResult? Function(String? message)? paymentMethodUnavailable,
    TResult? Function(String message)? unknownError,
  }) {
    return noToken?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noToken,
    TResult Function(String? message)? networkError,
    TResult Function(String? message)? invalidResponse,
    TResult Function(String? message)? preCheckFailed,
    TResult Function(String? url)? cannotLaunchUrl,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? invalidAmount,
    TResult Function(String? message)? paymentMethodUnavailable,
    TResult Function(String message)? unknownError,
    required TResult orElse(),
  }) {
    if (noToken != null) {
      return noToken();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NoTokenError value) noToken,
    required TResult Function(NetworkError value) networkError,
    required TResult Function(InvalidResponseError value) invalidResponse,
    required TResult Function(PreCheckError value) preCheckFailed,
    required TResult Function(UrlLaunchError value) cannotLaunchUrl,
    required TResult Function(PaymentTimeoutError value) timeout,
    required TResult Function(InvalidAmountError value) invalidAmount,
    required TResult Function(PaymentMethodUnavailableError value)
        paymentMethodUnavailable,
    required TResult Function(UnknownError value) unknownError,
  }) {
    return noToken(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NoTokenError value)? noToken,
    TResult? Function(NetworkError value)? networkError,
    TResult? Function(InvalidResponseError value)? invalidResponse,
    TResult? Function(PreCheckError value)? preCheckFailed,
    TResult? Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult? Function(PaymentTimeoutError value)? timeout,
    TResult? Function(InvalidAmountError value)? invalidAmount,
    TResult? Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult? Function(UnknownError value)? unknownError,
  }) {
    return noToken?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NoTokenError value)? noToken,
    TResult Function(NetworkError value)? networkError,
    TResult Function(InvalidResponseError value)? invalidResponse,
    TResult Function(PreCheckError value)? preCheckFailed,
    TResult Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult Function(PaymentTimeoutError value)? timeout,
    TResult Function(InvalidAmountError value)? invalidAmount,
    TResult Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult Function(UnknownError value)? unknownError,
    required TResult orElse(),
  }) {
    if (noToken != null) {
      return noToken(this);
    }
    return orElse();
  }
}

abstract class NoTokenError extends PaymentError {
  const factory NoTokenError() = _$NoTokenErrorImpl;
  const NoTokenError._() : super._();
}

/// @nodoc
abstract class _$$NetworkErrorImplCopyWith<$Res> {
  factory _$$NetworkErrorImplCopyWith(
          _$NetworkErrorImpl value, $Res Function(_$NetworkErrorImpl) then) =
      __$$NetworkErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$NetworkErrorImplCopyWithImpl<$Res>
    extends _$PaymentErrorCopyWithImpl<$Res, _$NetworkErrorImpl>
    implements _$$NetworkErrorImplCopyWith<$Res> {
  __$$NetworkErrorImplCopyWithImpl(
      _$NetworkErrorImpl _value, $Res Function(_$NetworkErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$NetworkErrorImpl(
      freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$NetworkErrorImpl extends NetworkError {
  const _$NetworkErrorImpl([this.message]) : super._();

  @override
  final String? message;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NetworkErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NetworkErrorImplCopyWith<_$NetworkErrorImpl> get copyWith =>
      __$$NetworkErrorImplCopyWithImpl<_$NetworkErrorImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noToken,
    required TResult Function(String? message) networkError,
    required TResult Function(String? message) invalidResponse,
    required TResult Function(String? message) preCheckFailed,
    required TResult Function(String? url) cannotLaunchUrl,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) invalidAmount,
    required TResult Function(String? message) paymentMethodUnavailable,
    required TResult Function(String message) unknownError,
  }) {
    return networkError(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noToken,
    TResult? Function(String? message)? networkError,
    TResult? Function(String? message)? invalidResponse,
    TResult? Function(String? message)? preCheckFailed,
    TResult? Function(String? url)? cannotLaunchUrl,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? invalidAmount,
    TResult? Function(String? message)? paymentMethodUnavailable,
    TResult? Function(String message)? unknownError,
  }) {
    return networkError?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noToken,
    TResult Function(String? message)? networkError,
    TResult Function(String? message)? invalidResponse,
    TResult Function(String? message)? preCheckFailed,
    TResult Function(String? url)? cannotLaunchUrl,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? invalidAmount,
    TResult Function(String? message)? paymentMethodUnavailable,
    TResult Function(String message)? unknownError,
    required TResult orElse(),
  }) {
    if (networkError != null) {
      return networkError(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NoTokenError value) noToken,
    required TResult Function(NetworkError value) networkError,
    required TResult Function(InvalidResponseError value) invalidResponse,
    required TResult Function(PreCheckError value) preCheckFailed,
    required TResult Function(UrlLaunchError value) cannotLaunchUrl,
    required TResult Function(PaymentTimeoutError value) timeout,
    required TResult Function(InvalidAmountError value) invalidAmount,
    required TResult Function(PaymentMethodUnavailableError value)
        paymentMethodUnavailable,
    required TResult Function(UnknownError value) unknownError,
  }) {
    return networkError(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NoTokenError value)? noToken,
    TResult? Function(NetworkError value)? networkError,
    TResult? Function(InvalidResponseError value)? invalidResponse,
    TResult? Function(PreCheckError value)? preCheckFailed,
    TResult? Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult? Function(PaymentTimeoutError value)? timeout,
    TResult? Function(InvalidAmountError value)? invalidAmount,
    TResult? Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult? Function(UnknownError value)? unknownError,
  }) {
    return networkError?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NoTokenError value)? noToken,
    TResult Function(NetworkError value)? networkError,
    TResult Function(InvalidResponseError value)? invalidResponse,
    TResult Function(PreCheckError value)? preCheckFailed,
    TResult Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult Function(PaymentTimeoutError value)? timeout,
    TResult Function(InvalidAmountError value)? invalidAmount,
    TResult Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult Function(UnknownError value)? unknownError,
    required TResult orElse(),
  }) {
    if (networkError != null) {
      return networkError(this);
    }
    return orElse();
  }
}

abstract class NetworkError extends PaymentError {
  const factory NetworkError([final String? message]) = _$NetworkErrorImpl;
  const NetworkError._() : super._();

  String? get message;

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NetworkErrorImplCopyWith<_$NetworkErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$InvalidResponseErrorImplCopyWith<$Res> {
  factory _$$InvalidResponseErrorImplCopyWith(_$InvalidResponseErrorImpl value,
          $Res Function(_$InvalidResponseErrorImpl) then) =
      __$$InvalidResponseErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$InvalidResponseErrorImplCopyWithImpl<$Res>
    extends _$PaymentErrorCopyWithImpl<$Res, _$InvalidResponseErrorImpl>
    implements _$$InvalidResponseErrorImplCopyWith<$Res> {
  __$$InvalidResponseErrorImplCopyWithImpl(_$InvalidResponseErrorImpl _value,
      $Res Function(_$InvalidResponseErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$InvalidResponseErrorImpl(
      freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$InvalidResponseErrorImpl extends InvalidResponseError {
  const _$InvalidResponseErrorImpl([this.message]) : super._();

  @override
  final String? message;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InvalidResponseErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InvalidResponseErrorImplCopyWith<_$InvalidResponseErrorImpl>
      get copyWith =>
          __$$InvalidResponseErrorImplCopyWithImpl<_$InvalidResponseErrorImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noToken,
    required TResult Function(String? message) networkError,
    required TResult Function(String? message) invalidResponse,
    required TResult Function(String? message) preCheckFailed,
    required TResult Function(String? url) cannotLaunchUrl,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) invalidAmount,
    required TResult Function(String? message) paymentMethodUnavailable,
    required TResult Function(String message) unknownError,
  }) {
    return invalidResponse(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noToken,
    TResult? Function(String? message)? networkError,
    TResult? Function(String? message)? invalidResponse,
    TResult? Function(String? message)? preCheckFailed,
    TResult? Function(String? url)? cannotLaunchUrl,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? invalidAmount,
    TResult? Function(String? message)? paymentMethodUnavailable,
    TResult? Function(String message)? unknownError,
  }) {
    return invalidResponse?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noToken,
    TResult Function(String? message)? networkError,
    TResult Function(String? message)? invalidResponse,
    TResult Function(String? message)? preCheckFailed,
    TResult Function(String? url)? cannotLaunchUrl,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? invalidAmount,
    TResult Function(String? message)? paymentMethodUnavailable,
    TResult Function(String message)? unknownError,
    required TResult orElse(),
  }) {
    if (invalidResponse != null) {
      return invalidResponse(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NoTokenError value) noToken,
    required TResult Function(NetworkError value) networkError,
    required TResult Function(InvalidResponseError value) invalidResponse,
    required TResult Function(PreCheckError value) preCheckFailed,
    required TResult Function(UrlLaunchError value) cannotLaunchUrl,
    required TResult Function(PaymentTimeoutError value) timeout,
    required TResult Function(InvalidAmountError value) invalidAmount,
    required TResult Function(PaymentMethodUnavailableError value)
        paymentMethodUnavailable,
    required TResult Function(UnknownError value) unknownError,
  }) {
    return invalidResponse(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NoTokenError value)? noToken,
    TResult? Function(NetworkError value)? networkError,
    TResult? Function(InvalidResponseError value)? invalidResponse,
    TResult? Function(PreCheckError value)? preCheckFailed,
    TResult? Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult? Function(PaymentTimeoutError value)? timeout,
    TResult? Function(InvalidAmountError value)? invalidAmount,
    TResult? Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult? Function(UnknownError value)? unknownError,
  }) {
    return invalidResponse?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NoTokenError value)? noToken,
    TResult Function(NetworkError value)? networkError,
    TResult Function(InvalidResponseError value)? invalidResponse,
    TResult Function(PreCheckError value)? preCheckFailed,
    TResult Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult Function(PaymentTimeoutError value)? timeout,
    TResult Function(InvalidAmountError value)? invalidAmount,
    TResult Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult Function(UnknownError value)? unknownError,
    required TResult orElse(),
  }) {
    if (invalidResponse != null) {
      return invalidResponse(this);
    }
    return orElse();
  }
}

abstract class InvalidResponseError extends PaymentError {
  const factory InvalidResponseError([final String? message]) =
      _$InvalidResponseErrorImpl;
  const InvalidResponseError._() : super._();

  String? get message;

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InvalidResponseErrorImplCopyWith<_$InvalidResponseErrorImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PreCheckErrorImplCopyWith<$Res> {
  factory _$$PreCheckErrorImplCopyWith(
          _$PreCheckErrorImpl value, $Res Function(_$PreCheckErrorImpl) then) =
      __$$PreCheckErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$PreCheckErrorImplCopyWithImpl<$Res>
    extends _$PaymentErrorCopyWithImpl<$Res, _$PreCheckErrorImpl>
    implements _$$PreCheckErrorImplCopyWith<$Res> {
  __$$PreCheckErrorImplCopyWithImpl(
      _$PreCheckErrorImpl _value, $Res Function(_$PreCheckErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$PreCheckErrorImpl(
      freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$PreCheckErrorImpl extends PreCheckError {
  const _$PreCheckErrorImpl([this.message]) : super._();

  @override
  final String? message;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PreCheckErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PreCheckErrorImplCopyWith<_$PreCheckErrorImpl> get copyWith =>
      __$$PreCheckErrorImplCopyWithImpl<_$PreCheckErrorImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noToken,
    required TResult Function(String? message) networkError,
    required TResult Function(String? message) invalidResponse,
    required TResult Function(String? message) preCheckFailed,
    required TResult Function(String? url) cannotLaunchUrl,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) invalidAmount,
    required TResult Function(String? message) paymentMethodUnavailable,
    required TResult Function(String message) unknownError,
  }) {
    return preCheckFailed(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noToken,
    TResult? Function(String? message)? networkError,
    TResult? Function(String? message)? invalidResponse,
    TResult? Function(String? message)? preCheckFailed,
    TResult? Function(String? url)? cannotLaunchUrl,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? invalidAmount,
    TResult? Function(String? message)? paymentMethodUnavailable,
    TResult? Function(String message)? unknownError,
  }) {
    return preCheckFailed?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noToken,
    TResult Function(String? message)? networkError,
    TResult Function(String? message)? invalidResponse,
    TResult Function(String? message)? preCheckFailed,
    TResult Function(String? url)? cannotLaunchUrl,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? invalidAmount,
    TResult Function(String? message)? paymentMethodUnavailable,
    TResult Function(String message)? unknownError,
    required TResult orElse(),
  }) {
    if (preCheckFailed != null) {
      return preCheckFailed(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NoTokenError value) noToken,
    required TResult Function(NetworkError value) networkError,
    required TResult Function(InvalidResponseError value) invalidResponse,
    required TResult Function(PreCheckError value) preCheckFailed,
    required TResult Function(UrlLaunchError value) cannotLaunchUrl,
    required TResult Function(PaymentTimeoutError value) timeout,
    required TResult Function(InvalidAmountError value) invalidAmount,
    required TResult Function(PaymentMethodUnavailableError value)
        paymentMethodUnavailable,
    required TResult Function(UnknownError value) unknownError,
  }) {
    return preCheckFailed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NoTokenError value)? noToken,
    TResult? Function(NetworkError value)? networkError,
    TResult? Function(InvalidResponseError value)? invalidResponse,
    TResult? Function(PreCheckError value)? preCheckFailed,
    TResult? Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult? Function(PaymentTimeoutError value)? timeout,
    TResult? Function(InvalidAmountError value)? invalidAmount,
    TResult? Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult? Function(UnknownError value)? unknownError,
  }) {
    return preCheckFailed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NoTokenError value)? noToken,
    TResult Function(NetworkError value)? networkError,
    TResult Function(InvalidResponseError value)? invalidResponse,
    TResult Function(PreCheckError value)? preCheckFailed,
    TResult Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult Function(PaymentTimeoutError value)? timeout,
    TResult Function(InvalidAmountError value)? invalidAmount,
    TResult Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult Function(UnknownError value)? unknownError,
    required TResult orElse(),
  }) {
    if (preCheckFailed != null) {
      return preCheckFailed(this);
    }
    return orElse();
  }
}

abstract class PreCheckError extends PaymentError {
  const factory PreCheckError([final String? message]) = _$PreCheckErrorImpl;
  const PreCheckError._() : super._();

  String? get message;

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PreCheckErrorImplCopyWith<_$PreCheckErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$UrlLaunchErrorImplCopyWith<$Res> {
  factory _$$UrlLaunchErrorImplCopyWith(_$UrlLaunchErrorImpl value,
          $Res Function(_$UrlLaunchErrorImpl) then) =
      __$$UrlLaunchErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String? url});
}

/// @nodoc
class __$$UrlLaunchErrorImplCopyWithImpl<$Res>
    extends _$PaymentErrorCopyWithImpl<$Res, _$UrlLaunchErrorImpl>
    implements _$$UrlLaunchErrorImplCopyWith<$Res> {
  __$$UrlLaunchErrorImplCopyWithImpl(
      _$UrlLaunchErrorImpl _value, $Res Function(_$UrlLaunchErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = freezed,
  }) {
    return _then(_$UrlLaunchErrorImpl(
      freezed == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$UrlLaunchErrorImpl extends UrlLaunchError {
  const _$UrlLaunchErrorImpl([this.url]) : super._();

  @override
  final String? url;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UrlLaunchErrorImpl &&
            (identical(other.url, url) || other.url == url));
  }

  @override
  int get hashCode => Object.hash(runtimeType, url);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UrlLaunchErrorImplCopyWith<_$UrlLaunchErrorImpl> get copyWith =>
      __$$UrlLaunchErrorImplCopyWithImpl<_$UrlLaunchErrorImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noToken,
    required TResult Function(String? message) networkError,
    required TResult Function(String? message) invalidResponse,
    required TResult Function(String? message) preCheckFailed,
    required TResult Function(String? url) cannotLaunchUrl,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) invalidAmount,
    required TResult Function(String? message) paymentMethodUnavailable,
    required TResult Function(String message) unknownError,
  }) {
    return cannotLaunchUrl(url);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noToken,
    TResult? Function(String? message)? networkError,
    TResult? Function(String? message)? invalidResponse,
    TResult? Function(String? message)? preCheckFailed,
    TResult? Function(String? url)? cannotLaunchUrl,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? invalidAmount,
    TResult? Function(String? message)? paymentMethodUnavailable,
    TResult? Function(String message)? unknownError,
  }) {
    return cannotLaunchUrl?.call(url);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noToken,
    TResult Function(String? message)? networkError,
    TResult Function(String? message)? invalidResponse,
    TResult Function(String? message)? preCheckFailed,
    TResult Function(String? url)? cannotLaunchUrl,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? invalidAmount,
    TResult Function(String? message)? paymentMethodUnavailable,
    TResult Function(String message)? unknownError,
    required TResult orElse(),
  }) {
    if (cannotLaunchUrl != null) {
      return cannotLaunchUrl(url);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NoTokenError value) noToken,
    required TResult Function(NetworkError value) networkError,
    required TResult Function(InvalidResponseError value) invalidResponse,
    required TResult Function(PreCheckError value) preCheckFailed,
    required TResult Function(UrlLaunchError value) cannotLaunchUrl,
    required TResult Function(PaymentTimeoutError value) timeout,
    required TResult Function(InvalidAmountError value) invalidAmount,
    required TResult Function(PaymentMethodUnavailableError value)
        paymentMethodUnavailable,
    required TResult Function(UnknownError value) unknownError,
  }) {
    return cannotLaunchUrl(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NoTokenError value)? noToken,
    TResult? Function(NetworkError value)? networkError,
    TResult? Function(InvalidResponseError value)? invalidResponse,
    TResult? Function(PreCheckError value)? preCheckFailed,
    TResult? Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult? Function(PaymentTimeoutError value)? timeout,
    TResult? Function(InvalidAmountError value)? invalidAmount,
    TResult? Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult? Function(UnknownError value)? unknownError,
  }) {
    return cannotLaunchUrl?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NoTokenError value)? noToken,
    TResult Function(NetworkError value)? networkError,
    TResult Function(InvalidResponseError value)? invalidResponse,
    TResult Function(PreCheckError value)? preCheckFailed,
    TResult Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult Function(PaymentTimeoutError value)? timeout,
    TResult Function(InvalidAmountError value)? invalidAmount,
    TResult Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult Function(UnknownError value)? unknownError,
    required TResult orElse(),
  }) {
    if (cannotLaunchUrl != null) {
      return cannotLaunchUrl(this);
    }
    return orElse();
  }
}

abstract class UrlLaunchError extends PaymentError {
  const factory UrlLaunchError([final String? url]) = _$UrlLaunchErrorImpl;
  const UrlLaunchError._() : super._();

  String? get url;

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UrlLaunchErrorImplCopyWith<_$UrlLaunchErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PaymentTimeoutErrorImplCopyWith<$Res> {
  factory _$$PaymentTimeoutErrorImplCopyWith(_$PaymentTimeoutErrorImpl value,
          $Res Function(_$PaymentTimeoutErrorImpl) then) =
      __$$PaymentTimeoutErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$PaymentTimeoutErrorImplCopyWithImpl<$Res>
    extends _$PaymentErrorCopyWithImpl<$Res, _$PaymentTimeoutErrorImpl>
    implements _$$PaymentTimeoutErrorImplCopyWith<$Res> {
  __$$PaymentTimeoutErrorImplCopyWithImpl(_$PaymentTimeoutErrorImpl _value,
      $Res Function(_$PaymentTimeoutErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$PaymentTimeoutErrorImpl(
      freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$PaymentTimeoutErrorImpl extends PaymentTimeoutError {
  const _$PaymentTimeoutErrorImpl([this.message]) : super._();

  @override
  final String? message;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentTimeoutErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentTimeoutErrorImplCopyWith<_$PaymentTimeoutErrorImpl> get copyWith =>
      __$$PaymentTimeoutErrorImplCopyWithImpl<_$PaymentTimeoutErrorImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noToken,
    required TResult Function(String? message) networkError,
    required TResult Function(String? message) invalidResponse,
    required TResult Function(String? message) preCheckFailed,
    required TResult Function(String? url) cannotLaunchUrl,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) invalidAmount,
    required TResult Function(String? message) paymentMethodUnavailable,
    required TResult Function(String message) unknownError,
  }) {
    return timeout(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noToken,
    TResult? Function(String? message)? networkError,
    TResult? Function(String? message)? invalidResponse,
    TResult? Function(String? message)? preCheckFailed,
    TResult? Function(String? url)? cannotLaunchUrl,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? invalidAmount,
    TResult? Function(String? message)? paymentMethodUnavailable,
    TResult? Function(String message)? unknownError,
  }) {
    return timeout?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noToken,
    TResult Function(String? message)? networkError,
    TResult Function(String? message)? invalidResponse,
    TResult Function(String? message)? preCheckFailed,
    TResult Function(String? url)? cannotLaunchUrl,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? invalidAmount,
    TResult Function(String? message)? paymentMethodUnavailable,
    TResult Function(String message)? unknownError,
    required TResult orElse(),
  }) {
    if (timeout != null) {
      return timeout(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NoTokenError value) noToken,
    required TResult Function(NetworkError value) networkError,
    required TResult Function(InvalidResponseError value) invalidResponse,
    required TResult Function(PreCheckError value) preCheckFailed,
    required TResult Function(UrlLaunchError value) cannotLaunchUrl,
    required TResult Function(PaymentTimeoutError value) timeout,
    required TResult Function(InvalidAmountError value) invalidAmount,
    required TResult Function(PaymentMethodUnavailableError value)
        paymentMethodUnavailable,
    required TResult Function(UnknownError value) unknownError,
  }) {
    return timeout(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NoTokenError value)? noToken,
    TResult? Function(NetworkError value)? networkError,
    TResult? Function(InvalidResponseError value)? invalidResponse,
    TResult? Function(PreCheckError value)? preCheckFailed,
    TResult? Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult? Function(PaymentTimeoutError value)? timeout,
    TResult? Function(InvalidAmountError value)? invalidAmount,
    TResult? Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult? Function(UnknownError value)? unknownError,
  }) {
    return timeout?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NoTokenError value)? noToken,
    TResult Function(NetworkError value)? networkError,
    TResult Function(InvalidResponseError value)? invalidResponse,
    TResult Function(PreCheckError value)? preCheckFailed,
    TResult Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult Function(PaymentTimeoutError value)? timeout,
    TResult Function(InvalidAmountError value)? invalidAmount,
    TResult Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult Function(UnknownError value)? unknownError,
    required TResult orElse(),
  }) {
    if (timeout != null) {
      return timeout(this);
    }
    return orElse();
  }
}

abstract class PaymentTimeoutError extends PaymentError {
  const factory PaymentTimeoutError([final String? message]) =
      _$PaymentTimeoutErrorImpl;
  const PaymentTimeoutError._() : super._();

  String? get message;

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentTimeoutErrorImplCopyWith<_$PaymentTimeoutErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$InvalidAmountErrorImplCopyWith<$Res> {
  factory _$$InvalidAmountErrorImplCopyWith(_$InvalidAmountErrorImpl value,
          $Res Function(_$InvalidAmountErrorImpl) then) =
      __$$InvalidAmountErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$InvalidAmountErrorImplCopyWithImpl<$Res>
    extends _$PaymentErrorCopyWithImpl<$Res, _$InvalidAmountErrorImpl>
    implements _$$InvalidAmountErrorImplCopyWith<$Res> {
  __$$InvalidAmountErrorImplCopyWithImpl(_$InvalidAmountErrorImpl _value,
      $Res Function(_$InvalidAmountErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$InvalidAmountErrorImpl(
      freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$InvalidAmountErrorImpl extends InvalidAmountError {
  const _$InvalidAmountErrorImpl([this.message]) : super._();

  @override
  final String? message;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InvalidAmountErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InvalidAmountErrorImplCopyWith<_$InvalidAmountErrorImpl> get copyWith =>
      __$$InvalidAmountErrorImplCopyWithImpl<_$InvalidAmountErrorImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noToken,
    required TResult Function(String? message) networkError,
    required TResult Function(String? message) invalidResponse,
    required TResult Function(String? message) preCheckFailed,
    required TResult Function(String? url) cannotLaunchUrl,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) invalidAmount,
    required TResult Function(String? message) paymentMethodUnavailable,
    required TResult Function(String message) unknownError,
  }) {
    return invalidAmount(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noToken,
    TResult? Function(String? message)? networkError,
    TResult? Function(String? message)? invalidResponse,
    TResult? Function(String? message)? preCheckFailed,
    TResult? Function(String? url)? cannotLaunchUrl,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? invalidAmount,
    TResult? Function(String? message)? paymentMethodUnavailable,
    TResult? Function(String message)? unknownError,
  }) {
    return invalidAmount?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noToken,
    TResult Function(String? message)? networkError,
    TResult Function(String? message)? invalidResponse,
    TResult Function(String? message)? preCheckFailed,
    TResult Function(String? url)? cannotLaunchUrl,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? invalidAmount,
    TResult Function(String? message)? paymentMethodUnavailable,
    TResult Function(String message)? unknownError,
    required TResult orElse(),
  }) {
    if (invalidAmount != null) {
      return invalidAmount(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NoTokenError value) noToken,
    required TResult Function(NetworkError value) networkError,
    required TResult Function(InvalidResponseError value) invalidResponse,
    required TResult Function(PreCheckError value) preCheckFailed,
    required TResult Function(UrlLaunchError value) cannotLaunchUrl,
    required TResult Function(PaymentTimeoutError value) timeout,
    required TResult Function(InvalidAmountError value) invalidAmount,
    required TResult Function(PaymentMethodUnavailableError value)
        paymentMethodUnavailable,
    required TResult Function(UnknownError value) unknownError,
  }) {
    return invalidAmount(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NoTokenError value)? noToken,
    TResult? Function(NetworkError value)? networkError,
    TResult? Function(InvalidResponseError value)? invalidResponse,
    TResult? Function(PreCheckError value)? preCheckFailed,
    TResult? Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult? Function(PaymentTimeoutError value)? timeout,
    TResult? Function(InvalidAmountError value)? invalidAmount,
    TResult? Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult? Function(UnknownError value)? unknownError,
  }) {
    return invalidAmount?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NoTokenError value)? noToken,
    TResult Function(NetworkError value)? networkError,
    TResult Function(InvalidResponseError value)? invalidResponse,
    TResult Function(PreCheckError value)? preCheckFailed,
    TResult Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult Function(PaymentTimeoutError value)? timeout,
    TResult Function(InvalidAmountError value)? invalidAmount,
    TResult Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult Function(UnknownError value)? unknownError,
    required TResult orElse(),
  }) {
    if (invalidAmount != null) {
      return invalidAmount(this);
    }
    return orElse();
  }
}

abstract class InvalidAmountError extends PaymentError {
  const factory InvalidAmountError([final String? message]) =
      _$InvalidAmountErrorImpl;
  const InvalidAmountError._() : super._();

  String? get message;

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InvalidAmountErrorImplCopyWith<_$InvalidAmountErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PaymentMethodUnavailableErrorImplCopyWith<$Res> {
  factory _$$PaymentMethodUnavailableErrorImplCopyWith(
          _$PaymentMethodUnavailableErrorImpl value,
          $Res Function(_$PaymentMethodUnavailableErrorImpl) then) =
      __$$PaymentMethodUnavailableErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String? message});
}

/// @nodoc
class __$$PaymentMethodUnavailableErrorImplCopyWithImpl<$Res>
    extends _$PaymentErrorCopyWithImpl<$Res,
        _$PaymentMethodUnavailableErrorImpl>
    implements _$$PaymentMethodUnavailableErrorImplCopyWith<$Res> {
  __$$PaymentMethodUnavailableErrorImplCopyWithImpl(
      _$PaymentMethodUnavailableErrorImpl _value,
      $Res Function(_$PaymentMethodUnavailableErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = freezed,
  }) {
    return _then(_$PaymentMethodUnavailableErrorImpl(
      freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$PaymentMethodUnavailableErrorImpl
    extends PaymentMethodUnavailableError {
  const _$PaymentMethodUnavailableErrorImpl([this.message]) : super._();

  @override
  final String? message;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentMethodUnavailableErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentMethodUnavailableErrorImplCopyWith<
          _$PaymentMethodUnavailableErrorImpl>
      get copyWith => __$$PaymentMethodUnavailableErrorImplCopyWithImpl<
          _$PaymentMethodUnavailableErrorImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noToken,
    required TResult Function(String? message) networkError,
    required TResult Function(String? message) invalidResponse,
    required TResult Function(String? message) preCheckFailed,
    required TResult Function(String? url) cannotLaunchUrl,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) invalidAmount,
    required TResult Function(String? message) paymentMethodUnavailable,
    required TResult Function(String message) unknownError,
  }) {
    return paymentMethodUnavailable(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noToken,
    TResult? Function(String? message)? networkError,
    TResult? Function(String? message)? invalidResponse,
    TResult? Function(String? message)? preCheckFailed,
    TResult? Function(String? url)? cannotLaunchUrl,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? invalidAmount,
    TResult? Function(String? message)? paymentMethodUnavailable,
    TResult? Function(String message)? unknownError,
  }) {
    return paymentMethodUnavailable?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noToken,
    TResult Function(String? message)? networkError,
    TResult Function(String? message)? invalidResponse,
    TResult Function(String? message)? preCheckFailed,
    TResult Function(String? url)? cannotLaunchUrl,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? invalidAmount,
    TResult Function(String? message)? paymentMethodUnavailable,
    TResult Function(String message)? unknownError,
    required TResult orElse(),
  }) {
    if (paymentMethodUnavailable != null) {
      return paymentMethodUnavailable(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NoTokenError value) noToken,
    required TResult Function(NetworkError value) networkError,
    required TResult Function(InvalidResponseError value) invalidResponse,
    required TResult Function(PreCheckError value) preCheckFailed,
    required TResult Function(UrlLaunchError value) cannotLaunchUrl,
    required TResult Function(PaymentTimeoutError value) timeout,
    required TResult Function(InvalidAmountError value) invalidAmount,
    required TResult Function(PaymentMethodUnavailableError value)
        paymentMethodUnavailable,
    required TResult Function(UnknownError value) unknownError,
  }) {
    return paymentMethodUnavailable(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NoTokenError value)? noToken,
    TResult? Function(NetworkError value)? networkError,
    TResult? Function(InvalidResponseError value)? invalidResponse,
    TResult? Function(PreCheckError value)? preCheckFailed,
    TResult? Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult? Function(PaymentTimeoutError value)? timeout,
    TResult? Function(InvalidAmountError value)? invalidAmount,
    TResult? Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult? Function(UnknownError value)? unknownError,
  }) {
    return paymentMethodUnavailable?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NoTokenError value)? noToken,
    TResult Function(NetworkError value)? networkError,
    TResult Function(InvalidResponseError value)? invalidResponse,
    TResult Function(PreCheckError value)? preCheckFailed,
    TResult Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult Function(PaymentTimeoutError value)? timeout,
    TResult Function(InvalidAmountError value)? invalidAmount,
    TResult Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult Function(UnknownError value)? unknownError,
    required TResult orElse(),
  }) {
    if (paymentMethodUnavailable != null) {
      return paymentMethodUnavailable(this);
    }
    return orElse();
  }
}

abstract class PaymentMethodUnavailableError extends PaymentError {
  const factory PaymentMethodUnavailableError([final String? message]) =
      _$PaymentMethodUnavailableErrorImpl;
  const PaymentMethodUnavailableError._() : super._();

  String? get message;

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentMethodUnavailableErrorImplCopyWith<
          _$PaymentMethodUnavailableErrorImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$UnknownErrorImplCopyWith<$Res> {
  factory _$$UnknownErrorImplCopyWith(
          _$UnknownErrorImpl value, $Res Function(_$UnknownErrorImpl) then) =
      __$$UnknownErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$UnknownErrorImplCopyWithImpl<$Res>
    extends _$PaymentErrorCopyWithImpl<$Res, _$UnknownErrorImpl>
    implements _$$UnknownErrorImplCopyWith<$Res> {
  __$$UnknownErrorImplCopyWithImpl(
      _$UnknownErrorImpl _value, $Res Function(_$UnknownErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$UnknownErrorImpl(
      null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$UnknownErrorImpl extends UnknownError {
  const _$UnknownErrorImpl(this.message) : super._();

  @override
  final String message;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UnknownErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UnknownErrorImplCopyWith<_$UnknownErrorImpl> get copyWith =>
      __$$UnknownErrorImplCopyWithImpl<_$UnknownErrorImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() noToken,
    required TResult Function(String? message) networkError,
    required TResult Function(String? message) invalidResponse,
    required TResult Function(String? message) preCheckFailed,
    required TResult Function(String? url) cannotLaunchUrl,
    required TResult Function(String? message) timeout,
    required TResult Function(String? message) invalidAmount,
    required TResult Function(String? message) paymentMethodUnavailable,
    required TResult Function(String message) unknownError,
  }) {
    return unknownError(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? noToken,
    TResult? Function(String? message)? networkError,
    TResult? Function(String? message)? invalidResponse,
    TResult? Function(String? message)? preCheckFailed,
    TResult? Function(String? url)? cannotLaunchUrl,
    TResult? Function(String? message)? timeout,
    TResult? Function(String? message)? invalidAmount,
    TResult? Function(String? message)? paymentMethodUnavailable,
    TResult? Function(String message)? unknownError,
  }) {
    return unknownError?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? noToken,
    TResult Function(String? message)? networkError,
    TResult Function(String? message)? invalidResponse,
    TResult Function(String? message)? preCheckFailed,
    TResult Function(String? url)? cannotLaunchUrl,
    TResult Function(String? message)? timeout,
    TResult Function(String? message)? invalidAmount,
    TResult Function(String? message)? paymentMethodUnavailable,
    TResult Function(String message)? unknownError,
    required TResult orElse(),
  }) {
    if (unknownError != null) {
      return unknownError(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(NoTokenError value) noToken,
    required TResult Function(NetworkError value) networkError,
    required TResult Function(InvalidResponseError value) invalidResponse,
    required TResult Function(PreCheckError value) preCheckFailed,
    required TResult Function(UrlLaunchError value) cannotLaunchUrl,
    required TResult Function(PaymentTimeoutError value) timeout,
    required TResult Function(InvalidAmountError value) invalidAmount,
    required TResult Function(PaymentMethodUnavailableError value)
        paymentMethodUnavailable,
    required TResult Function(UnknownError value) unknownError,
  }) {
    return unknownError(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(NoTokenError value)? noToken,
    TResult? Function(NetworkError value)? networkError,
    TResult? Function(InvalidResponseError value)? invalidResponse,
    TResult? Function(PreCheckError value)? preCheckFailed,
    TResult? Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult? Function(PaymentTimeoutError value)? timeout,
    TResult? Function(InvalidAmountError value)? invalidAmount,
    TResult? Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult? Function(UnknownError value)? unknownError,
  }) {
    return unknownError?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(NoTokenError value)? noToken,
    TResult Function(NetworkError value)? networkError,
    TResult Function(InvalidResponseError value)? invalidResponse,
    TResult Function(PreCheckError value)? preCheckFailed,
    TResult Function(UrlLaunchError value)? cannotLaunchUrl,
    TResult Function(PaymentTimeoutError value)? timeout,
    TResult Function(InvalidAmountError value)? invalidAmount,
    TResult Function(PaymentMethodUnavailableError value)?
        paymentMethodUnavailable,
    TResult Function(UnknownError value)? unknownError,
    required TResult orElse(),
  }) {
    if (unknownError != null) {
      return unknownError(this);
    }
    return orElse();
  }
}

abstract class UnknownError extends PaymentError {
  const factory UnknownError(final String message) = _$UnknownErrorImpl;
  const UnknownError._() : super._();

  String get message;

  /// Create a copy of PaymentError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UnknownErrorImplCopyWith<_$UnknownErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PaymentState {
  PaymentOrderInfo? get orderInfo => throw _privateConstructorUsedError;
  PaymentStatus get status => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  List<PaymentMethodInfo> get paymentMethods =>
      throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  PaymentResult? get result => throw _privateConstructorUsedError;

  /// Create a copy of PaymentState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaymentStateCopyWith<PaymentState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentStateCopyWith<$Res> {
  factory $PaymentStateCopyWith(
          PaymentState value, $Res Function(PaymentState) then) =
      _$PaymentStateCopyWithImpl<$Res, PaymentState>;
  @useResult
  $Res call(
      {PaymentOrderInfo? orderInfo,
      PaymentStatus status,
      String? error,
      List<PaymentMethodInfo> paymentMethods,
      bool isLoading,
      PaymentResult? result});

  $PaymentOrderInfoCopyWith<$Res>? get orderInfo;
  $PaymentResultCopyWith<$Res>? get result;
}

/// @nodoc
class _$PaymentStateCopyWithImpl<$Res, $Val extends PaymentState>
    implements $PaymentStateCopyWith<$Res> {
  _$PaymentStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? orderInfo = freezed,
    Object? status = null,
    Object? error = freezed,
    Object? paymentMethods = null,
    Object? isLoading = null,
    Object? result = freezed,
  }) {
    return _then(_value.copyWith(
      orderInfo: freezed == orderInfo
          ? _value.orderInfo
          : orderInfo // ignore: cast_nullable_to_non_nullable
              as PaymentOrderInfo?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as PaymentStatus,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      paymentMethods: null == paymentMethods
          ? _value.paymentMethods
          : paymentMethods // ignore: cast_nullable_to_non_nullable
              as List<PaymentMethodInfo>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      result: freezed == result
          ? _value.result
          : result // ignore: cast_nullable_to_non_nullable
              as PaymentResult?,
    ) as $Val);
  }

  /// Create a copy of PaymentState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PaymentOrderInfoCopyWith<$Res>? get orderInfo {
    if (_value.orderInfo == null) {
      return null;
    }

    return $PaymentOrderInfoCopyWith<$Res>(_value.orderInfo!, (value) {
      return _then(_value.copyWith(orderInfo: value) as $Val);
    });
  }

  /// Create a copy of PaymentState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PaymentResultCopyWith<$Res>? get result {
    if (_value.result == null) {
      return null;
    }

    return $PaymentResultCopyWith<$Res>(_value.result!, (value) {
      return _then(_value.copyWith(result: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PaymentStateImplCopyWith<$Res>
    implements $PaymentStateCopyWith<$Res> {
  factory _$$PaymentStateImplCopyWith(
          _$PaymentStateImpl value, $Res Function(_$PaymentStateImpl) then) =
      __$$PaymentStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {PaymentOrderInfo? orderInfo,
      PaymentStatus status,
      String? error,
      List<PaymentMethodInfo> paymentMethods,
      bool isLoading,
      PaymentResult? result});

  @override
  $PaymentOrderInfoCopyWith<$Res>? get orderInfo;
  @override
  $PaymentResultCopyWith<$Res>? get result;
}

/// @nodoc
class __$$PaymentStateImplCopyWithImpl<$Res>
    extends _$PaymentStateCopyWithImpl<$Res, _$PaymentStateImpl>
    implements _$$PaymentStateImplCopyWith<$Res> {
  __$$PaymentStateImplCopyWithImpl(
      _$PaymentStateImpl _value, $Res Function(_$PaymentStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? orderInfo = freezed,
    Object? status = null,
    Object? error = freezed,
    Object? paymentMethods = null,
    Object? isLoading = null,
    Object? result = freezed,
  }) {
    return _then(_$PaymentStateImpl(
      orderInfo: freezed == orderInfo
          ? _value.orderInfo
          : orderInfo // ignore: cast_nullable_to_non_nullable
              as PaymentOrderInfo?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as PaymentStatus,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      paymentMethods: null == paymentMethods
          ? _value._paymentMethods
          : paymentMethods // ignore: cast_nullable_to_non_nullable
              as List<PaymentMethodInfo>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      result: freezed == result
          ? _value.result
          : result // ignore: cast_nullable_to_non_nullable
              as PaymentResult?,
    ));
  }
}

/// @nodoc

class _$PaymentStateImpl extends _PaymentState {
  const _$PaymentStateImpl(
      {this.orderInfo,
      this.status = PaymentStatus.initial,
      this.error,
      final List<PaymentMethodInfo> paymentMethods = const [],
      this.isLoading = false,
      this.result})
      : _paymentMethods = paymentMethods,
        super._();

  @override
  final PaymentOrderInfo? orderInfo;
  @override
  @JsonKey()
  final PaymentStatus status;
  @override
  final String? error;
  final List<PaymentMethodInfo> _paymentMethods;
  @override
  @JsonKey()
  List<PaymentMethodInfo> get paymentMethods {
    if (_paymentMethods is EqualUnmodifiableListView) return _paymentMethods;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_paymentMethods);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final PaymentResult? result;

  @override
  String toString() {
    return 'PaymentState(orderInfo: $orderInfo, status: $status, error: $error, paymentMethods: $paymentMethods, isLoading: $isLoading, result: $result)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentStateImpl &&
            (identical(other.orderInfo, orderInfo) ||
                other.orderInfo == orderInfo) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.error, error) || other.error == error) &&
            const DeepCollectionEquality()
                .equals(other._paymentMethods, _paymentMethods) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.result, result) || other.result == result));
  }

  @override
  int get hashCode => Object.hash(runtimeType, orderInfo, status, error,
      const DeepCollectionEquality().hash(_paymentMethods), isLoading, result);

  /// Create a copy of PaymentState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentStateImplCopyWith<_$PaymentStateImpl> get copyWith =>
      __$$PaymentStateImplCopyWithImpl<_$PaymentStateImpl>(this, _$identity);
}

abstract class _PaymentState extends PaymentState {
  const factory _PaymentState(
      {final PaymentOrderInfo? orderInfo,
      final PaymentStatus status,
      final String? error,
      final List<PaymentMethodInfo> paymentMethods,
      final bool isLoading,
      final PaymentResult? result}) = _$PaymentStateImpl;
  const _PaymentState._() : super._();

  @override
  PaymentOrderInfo? get orderInfo;
  @override
  PaymentStatus get status;
  @override
  String? get error;
  @override
  List<PaymentMethodInfo> get paymentMethods;
  @override
  bool get isLoading;
  @override
  PaymentResult? get result;

  /// Create a copy of PaymentState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentStateImplCopyWith<_$PaymentStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PaymentRequest _$PaymentRequestFromJson(Map<String, dynamic> json) {
  return _PaymentRequest.fromJson(json);
}

/// @nodoc
mixin _$PaymentRequest {
  @JsonKey(name: 'trade_no')
  String get tradeNo => throw _privateConstructorUsedError;
  String get method => throw _privateConstructorUsedError;

  /// Serializes this PaymentRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PaymentRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaymentRequestCopyWith<PaymentRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentRequestCopyWith<$Res> {
  factory $PaymentRequestCopyWith(
          PaymentRequest value, $Res Function(PaymentRequest) then) =
      _$PaymentRequestCopyWithImpl<$Res, PaymentRequest>;
  @useResult
  $Res call({@JsonKey(name: 'trade_no') String tradeNo, String method});
}

/// @nodoc
class _$PaymentRequestCopyWithImpl<$Res, $Val extends PaymentRequest>
    implements $PaymentRequestCopyWith<$Res> {
  _$PaymentRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tradeNo = null,
    Object? method = null,
  }) {
    return _then(_value.copyWith(
      tradeNo: null == tradeNo
          ? _value.tradeNo
          : tradeNo // ignore: cast_nullable_to_non_nullable
              as String,
      method: null == method
          ? _value.method
          : method // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PaymentRequestImplCopyWith<$Res>
    implements $PaymentRequestCopyWith<$Res> {
  factory _$$PaymentRequestImplCopyWith(_$PaymentRequestImpl value,
          $Res Function(_$PaymentRequestImpl) then) =
      __$$PaymentRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({@JsonKey(name: 'trade_no') String tradeNo, String method});
}

/// @nodoc
class __$$PaymentRequestImplCopyWithImpl<$Res>
    extends _$PaymentRequestCopyWithImpl<$Res, _$PaymentRequestImpl>
    implements _$$PaymentRequestImplCopyWith<$Res> {
  __$$PaymentRequestImplCopyWithImpl(
      _$PaymentRequestImpl _value, $Res Function(_$PaymentRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tradeNo = null,
    Object? method = null,
  }) {
    return _then(_$PaymentRequestImpl(
      tradeNo: null == tradeNo
          ? _value.tradeNo
          : tradeNo // ignore: cast_nullable_to_non_nullable
              as String,
      method: null == method
          ? _value.method
          : method // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaymentRequestImpl implements _PaymentRequest {
  const _$PaymentRequestImpl(
      {@JsonKey(name: 'trade_no') required this.tradeNo, required this.method});

  factory _$PaymentRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentRequestImplFromJson(json);

  @override
  @JsonKey(name: 'trade_no')
  final String tradeNo;
  @override
  final String method;

  @override
  String toString() {
    return 'PaymentRequest(tradeNo: $tradeNo, method: $method)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentRequestImpl &&
            (identical(other.tradeNo, tradeNo) || other.tradeNo == tradeNo) &&
            (identical(other.method, method) || other.method == method));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, tradeNo, method);

  /// Create a copy of PaymentRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentRequestImplCopyWith<_$PaymentRequestImpl> get copyWith =>
      __$$PaymentRequestImplCopyWithImpl<_$PaymentRequestImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentRequestImplToJson(
      this,
    );
  }
}

abstract class _PaymentRequest implements PaymentRequest {
  const factory _PaymentRequest(
      {@JsonKey(name: 'trade_no') required final String tradeNo,
      required final String method}) = _$PaymentRequestImpl;

  factory _PaymentRequest.fromJson(Map<String, dynamic> json) =
      _$PaymentRequestImpl.fromJson;

  @override
  @JsonKey(name: 'trade_no')
  String get tradeNo;
  @override
  String get method;

  /// Create a copy of PaymentRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentRequestImplCopyWith<_$PaymentRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PaymentResponse _$PaymentResponseFromJson(Map<String, dynamic> json) {
  return _PaymentResponse.fromJson(json);
}

/// @nodoc
mixin _$PaymentResponse {
  bool get success => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;
  PaymentResult? get result => throw _privateConstructorUsedError;
  Map<String, dynamic>? get data => throw _privateConstructorUsedError;

  /// Serializes this PaymentResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PaymentResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaymentResponseCopyWith<PaymentResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentResponseCopyWith<$Res> {
  factory $PaymentResponseCopyWith(
          PaymentResponse value, $Res Function(PaymentResponse) then) =
      _$PaymentResponseCopyWithImpl<$Res, PaymentResponse>;
  @useResult
  $Res call(
      {bool success,
      String? message,
      PaymentResult? result,
      Map<String, dynamic>? data});

  $PaymentResultCopyWith<$Res>? get result;
}

/// @nodoc
class _$PaymentResponseCopyWithImpl<$Res, $Val extends PaymentResponse>
    implements $PaymentResponseCopyWith<$Res> {
  _$PaymentResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? message = freezed,
    Object? result = freezed,
    Object? data = freezed,
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
      result: freezed == result
          ? _value.result
          : result // ignore: cast_nullable_to_non_nullable
              as PaymentResult?,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }

  /// Create a copy of PaymentResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PaymentResultCopyWith<$Res>? get result {
    if (_value.result == null) {
      return null;
    }

    return $PaymentResultCopyWith<$Res>(_value.result!, (value) {
      return _then(_value.copyWith(result: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PaymentResponseImplCopyWith<$Res>
    implements $PaymentResponseCopyWith<$Res> {
  factory _$$PaymentResponseImplCopyWith(_$PaymentResponseImpl value,
          $Res Function(_$PaymentResponseImpl) then) =
      __$$PaymentResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool success,
      String? message,
      PaymentResult? result,
      Map<String, dynamic>? data});

  @override
  $PaymentResultCopyWith<$Res>? get result;
}

/// @nodoc
class __$$PaymentResponseImplCopyWithImpl<$Res>
    extends _$PaymentResponseCopyWithImpl<$Res, _$PaymentResponseImpl>
    implements _$$PaymentResponseImplCopyWith<$Res> {
  __$$PaymentResponseImplCopyWithImpl(
      _$PaymentResponseImpl _value, $Res Function(_$PaymentResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? message = freezed,
    Object? result = freezed,
    Object? data = freezed,
  }) {
    return _then(_$PaymentResponseImpl(
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      result: freezed == result
          ? _value.result
          : result // ignore: cast_nullable_to_non_nullable
              as PaymentResult?,
      data: freezed == data
          ? _value._data
          : data // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaymentResponseImpl implements _PaymentResponse {
  const _$PaymentResponseImpl(
      {required this.success,
      this.message,
      this.result,
      final Map<String, dynamic>? data})
      : _data = data;

  factory _$PaymentResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentResponseImplFromJson(json);

  @override
  final bool success;
  @override
  final String? message;
  @override
  final PaymentResult? result;
  final Map<String, dynamic>? _data;
  @override
  Map<String, dynamic>? get data {
    final value = _data;
    if (value == null) return null;
    if (_data is EqualUnmodifiableMapView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'PaymentResponse(success: $success, message: $message, result: $result, data: $data)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentResponseImpl &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.result, result) || other.result == result) &&
            const DeepCollectionEquality().equals(other._data, _data));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, success, message, result,
      const DeepCollectionEquality().hash(_data));

  /// Create a copy of PaymentResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentResponseImplCopyWith<_$PaymentResponseImpl> get copyWith =>
      __$$PaymentResponseImplCopyWithImpl<_$PaymentResponseImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentResponseImplToJson(
      this,
    );
  }
}

abstract class _PaymentResponse implements PaymentResponse {
  const factory _PaymentResponse(
      {required final bool success,
      final String? message,
      final PaymentResult? result,
      final Map<String, dynamic>? data}) = _$PaymentResponseImpl;

  factory _PaymentResponse.fromJson(Map<String, dynamic> json) =
      _$PaymentResponseImpl.fromJson;

  @override
  bool get success;
  @override
  String? get message;
  @override
  PaymentResult? get result;
  @override
  Map<String, dynamic>? get data;

  /// Create a copy of PaymentResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentResponseImplCopyWith<_$PaymentResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
