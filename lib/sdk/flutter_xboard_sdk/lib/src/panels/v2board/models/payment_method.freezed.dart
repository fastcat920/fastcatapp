// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_method.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PaymentMethod _$PaymentMethodFromJson(Map<String, dynamic> json) {
  return _PaymentMethod.fromJson(json);
}

/// @nodoc
mixin _$PaymentMethod {
  int get id => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  String? get payment => throw _privateConstructorUsedError;
  String? get icon => throw _privateConstructorUsedError;
  int? get show => throw _privateConstructorUsedError;
  String? get config => throw _privateConstructorUsedError;
  @JsonKey(name: 'handling_fee_fixed')
  int? get handlingFeeFixed => throw _privateConstructorUsedError;
  @JsonKey(name: 'handling_fee_percent')
  double? get handlingFeePercent => throw _privateConstructorUsedError;

  /// Serializes this PaymentMethod to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaymentMethodCopyWith<PaymentMethod> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentMethodCopyWith<$Res> {
  factory $PaymentMethodCopyWith(
          PaymentMethod value, $Res Function(PaymentMethod) then) =
      _$PaymentMethodCopyWithImpl<$Res, PaymentMethod>;
  @useResult
  $Res call(
      {int id,
      String? name,
      String? payment,
      String? icon,
      int? show,
      String? config,
      @JsonKey(name: 'handling_fee_fixed') int? handlingFeeFixed,
      @JsonKey(name: 'handling_fee_percent') double? handlingFeePercent});
}

/// @nodoc
class _$PaymentMethodCopyWithImpl<$Res, $Val extends PaymentMethod>
    implements $PaymentMethodCopyWith<$Res> {
  _$PaymentMethodCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = freezed,
    Object? payment = freezed,
    Object? icon = freezed,
    Object? show = freezed,
    Object? config = freezed,
    Object? handlingFeeFixed = freezed,
    Object? handlingFeePercent = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      payment: freezed == payment
          ? _value.payment
          : payment // ignore: cast_nullable_to_non_nullable
              as String?,
      icon: freezed == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String?,
      show: freezed == show
          ? _value.show
          : show // ignore: cast_nullable_to_non_nullable
              as int?,
      config: freezed == config
          ? _value.config
          : config // ignore: cast_nullable_to_non_nullable
              as String?,
      handlingFeeFixed: freezed == handlingFeeFixed
          ? _value.handlingFeeFixed
          : handlingFeeFixed // ignore: cast_nullable_to_non_nullable
              as int?,
      handlingFeePercent: freezed == handlingFeePercent
          ? _value.handlingFeePercent
          : handlingFeePercent // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PaymentMethodImplCopyWith<$Res>
    implements $PaymentMethodCopyWith<$Res> {
  factory _$$PaymentMethodImplCopyWith(
          _$PaymentMethodImpl value, $Res Function(_$PaymentMethodImpl) then) =
      __$$PaymentMethodImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      String? name,
      String? payment,
      String? icon,
      int? show,
      String? config,
      @JsonKey(name: 'handling_fee_fixed') int? handlingFeeFixed,
      @JsonKey(name: 'handling_fee_percent') double? handlingFeePercent});
}

/// @nodoc
class __$$PaymentMethodImplCopyWithImpl<$Res>
    extends _$PaymentMethodCopyWithImpl<$Res, _$PaymentMethodImpl>
    implements _$$PaymentMethodImplCopyWith<$Res> {
  __$$PaymentMethodImplCopyWithImpl(
      _$PaymentMethodImpl _value, $Res Function(_$PaymentMethodImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = freezed,
    Object? payment = freezed,
    Object? icon = freezed,
    Object? show = freezed,
    Object? config = freezed,
    Object? handlingFeeFixed = freezed,
    Object? handlingFeePercent = freezed,
  }) {
    return _then(_$PaymentMethodImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      payment: freezed == payment
          ? _value.payment
          : payment // ignore: cast_nullable_to_non_nullable
              as String?,
      icon: freezed == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String?,
      show: freezed == show
          ? _value.show
          : show // ignore: cast_nullable_to_non_nullable
              as int?,
      config: freezed == config
          ? _value.config
          : config // ignore: cast_nullable_to_non_nullable
              as String?,
      handlingFeeFixed: freezed == handlingFeeFixed
          ? _value.handlingFeeFixed
          : handlingFeeFixed // ignore: cast_nullable_to_non_nullable
              as int?,
      handlingFeePercent: freezed == handlingFeePercent
          ? _value.handlingFeePercent
          : handlingFeePercent // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaymentMethodImpl extends _PaymentMethod {
  const _$PaymentMethodImpl(
      {required this.id,
      this.name,
      this.payment,
      this.icon,
      this.show,
      this.config,
      @JsonKey(name: 'handling_fee_fixed') this.handlingFeeFixed,
      @JsonKey(name: 'handling_fee_percent') this.handlingFeePercent})
      : super._();

  factory _$PaymentMethodImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentMethodImplFromJson(json);

  @override
  final int id;
  @override
  final String? name;
  @override
  final String? payment;
  @override
  final String? icon;
  @override
  final int? show;
  @override
  final String? config;
  @override
  @JsonKey(name: 'handling_fee_fixed')
  final int? handlingFeeFixed;
  @override
  @JsonKey(name: 'handling_fee_percent')
  final double? handlingFeePercent;

  @override
  String toString() {
    return 'PaymentMethod(id: $id, name: $name, payment: $payment, icon: $icon, show: $show, config: $config, handlingFeeFixed: $handlingFeeFixed, handlingFeePercent: $handlingFeePercent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentMethodImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.payment, payment) || other.payment == payment) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.show, show) || other.show == show) &&
            (identical(other.config, config) || other.config == config) &&
            (identical(other.handlingFeeFixed, handlingFeeFixed) ||
                other.handlingFeeFixed == handlingFeeFixed) &&
            (identical(other.handlingFeePercent, handlingFeePercent) ||
                other.handlingFeePercent == handlingFeePercent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, payment, icon, show,
      config, handlingFeeFixed, handlingFeePercent);

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentMethodImplCopyWith<_$PaymentMethodImpl> get copyWith =>
      __$$PaymentMethodImplCopyWithImpl<_$PaymentMethodImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentMethodImplToJson(
      this,
    );
  }
}

abstract class _PaymentMethod extends PaymentMethod {
  const factory _PaymentMethod(
      {required final int id,
      final String? name,
      final String? payment,
      final String? icon,
      final int? show,
      final String? config,
      @JsonKey(name: 'handling_fee_fixed') final int? handlingFeeFixed,
      @JsonKey(name: 'handling_fee_percent')
      final double? handlingFeePercent}) = _$PaymentMethodImpl;
  const _PaymentMethod._() : super._();

  factory _PaymentMethod.fromJson(Map<String, dynamic> json) =
      _$PaymentMethodImpl.fromJson;

  @override
  int get id;
  @override
  String? get name;
  @override
  String? get payment;
  @override
  String? get icon;
  @override
  int? get show;
  @override
  String? get config;
  @override
  @JsonKey(name: 'handling_fee_fixed')
  int? get handlingFeeFixed;
  @override
  @JsonKey(name: 'handling_fee_percent')
  double? get handlingFeePercent;

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentMethodImplCopyWith<_$PaymentMethodImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
