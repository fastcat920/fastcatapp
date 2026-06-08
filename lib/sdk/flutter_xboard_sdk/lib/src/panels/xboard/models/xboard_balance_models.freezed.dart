// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'xboard_balance_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SystemConfig _$SystemConfigFromJson(Map<String, dynamic> json) {
  return _SystemConfig.fromJson(json);
}

/// @nodoc
mixin _$SystemConfig {
  @JsonKey(name: 'withdraw_methods')
  List<String> get withdrawMethods => throw _privateConstructorUsedError;
  @JsonKey(name: 'withdraw_close', fromJson: _intToBool, toJson: _boolToInt)
  bool get withdrawEnabled => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  @JsonKey(name: 'currency_symbol')
  String get currencySymbol => throw _privateConstructorUsedError;

  /// Serializes this SystemConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SystemConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SystemConfigCopyWith<SystemConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SystemConfigCopyWith<$Res> {
  factory $SystemConfigCopyWith(
          SystemConfig value, $Res Function(SystemConfig) then) =
      _$SystemConfigCopyWithImpl<$Res, SystemConfig>;
  @useResult
  $Res call(
      {@JsonKey(name: 'withdraw_methods') List<String> withdrawMethods,
      @JsonKey(name: 'withdraw_close', fromJson: _intToBool, toJson: _boolToInt)
      bool withdrawEnabled,
      String currency,
      @JsonKey(name: 'currency_symbol') String currencySymbol});
}

/// @nodoc
class _$SystemConfigCopyWithImpl<$Res, $Val extends SystemConfig>
    implements $SystemConfigCopyWith<$Res> {
  _$SystemConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SystemConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? withdrawMethods = null,
    Object? withdrawEnabled = null,
    Object? currency = null,
    Object? currencySymbol = null,
  }) {
    return _then(_value.copyWith(
      withdrawMethods: null == withdrawMethods
          ? _value.withdrawMethods
          : withdrawMethods // ignore: cast_nullable_to_non_nullable
              as List<String>,
      withdrawEnabled: null == withdrawEnabled
          ? _value.withdrawEnabled
          : withdrawEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      currencySymbol: null == currencySymbol
          ? _value.currencySymbol
          : currencySymbol // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SystemConfigImplCopyWith<$Res>
    implements $SystemConfigCopyWith<$Res> {
  factory _$$SystemConfigImplCopyWith(
          _$SystemConfigImpl value, $Res Function(_$SystemConfigImpl) then) =
      __$$SystemConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'withdraw_methods') List<String> withdrawMethods,
      @JsonKey(name: 'withdraw_close', fromJson: _intToBool, toJson: _boolToInt)
      bool withdrawEnabled,
      String currency,
      @JsonKey(name: 'currency_symbol') String currencySymbol});
}

/// @nodoc
class __$$SystemConfigImplCopyWithImpl<$Res>
    extends _$SystemConfigCopyWithImpl<$Res, _$SystemConfigImpl>
    implements _$$SystemConfigImplCopyWith<$Res> {
  __$$SystemConfigImplCopyWithImpl(
      _$SystemConfigImpl _value, $Res Function(_$SystemConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of SystemConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? withdrawMethods = null,
    Object? withdrawEnabled = null,
    Object? currency = null,
    Object? currencySymbol = null,
  }) {
    return _then(_$SystemConfigImpl(
      withdrawMethods: null == withdrawMethods
          ? _value._withdrawMethods
          : withdrawMethods // ignore: cast_nullable_to_non_nullable
              as List<String>,
      withdrawEnabled: null == withdrawEnabled
          ? _value.withdrawEnabled
          : withdrawEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      currencySymbol: null == currencySymbol
          ? _value.currencySymbol
          : currencySymbol // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SystemConfigImpl implements _SystemConfig {
  const _$SystemConfigImpl(
      {@JsonKey(name: 'withdraw_methods')
      required final List<String> withdrawMethods,
      @JsonKey(name: 'withdraw_close', fromJson: _intToBool, toJson: _boolToInt)
      required this.withdrawEnabled,
      required this.currency,
      @JsonKey(name: 'currency_symbol') required this.currencySymbol})
      : _withdrawMethods = withdrawMethods;

  factory _$SystemConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$SystemConfigImplFromJson(json);

  final List<String> _withdrawMethods;
  @override
  @JsonKey(name: 'withdraw_methods')
  List<String> get withdrawMethods {
    if (_withdrawMethods is EqualUnmodifiableListView) return _withdrawMethods;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_withdrawMethods);
  }

  @override
  @JsonKey(name: 'withdraw_close', fromJson: _intToBool, toJson: _boolToInt)
  final bool withdrawEnabled;
  @override
  final String currency;
  @override
  @JsonKey(name: 'currency_symbol')
  final String currencySymbol;

  @override
  String toString() {
    return 'SystemConfig(withdrawMethods: $withdrawMethods, withdrawEnabled: $withdrawEnabled, currency: $currency, currencySymbol: $currencySymbol)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SystemConfigImpl &&
            const DeepCollectionEquality()
                .equals(other._withdrawMethods, _withdrawMethods) &&
            (identical(other.withdrawEnabled, withdrawEnabled) ||
                other.withdrawEnabled == withdrawEnabled) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.currencySymbol, currencySymbol) ||
                other.currencySymbol == currencySymbol));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_withdrawMethods),
      withdrawEnabled,
      currency,
      currencySymbol);

  /// Create a copy of SystemConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SystemConfigImplCopyWith<_$SystemConfigImpl> get copyWith =>
      __$$SystemConfigImplCopyWithImpl<_$SystemConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SystemConfigImplToJson(
      this,
    );
  }
}

abstract class _SystemConfig implements SystemConfig {
  const factory _SystemConfig(
      {@JsonKey(name: 'withdraw_methods')
      required final List<String> withdrawMethods,
      @JsonKey(name: 'withdraw_close', fromJson: _intToBool, toJson: _boolToInt)
      required final bool withdrawEnabled,
      required final String currency,
      @JsonKey(name: 'currency_symbol')
      required final String currencySymbol}) = _$SystemConfigImpl;

  factory _SystemConfig.fromJson(Map<String, dynamic> json) =
      _$SystemConfigImpl.fromJson;

  @override
  @JsonKey(name: 'withdraw_methods')
  List<String> get withdrawMethods;
  @override
  @JsonKey(name: 'withdraw_close', fromJson: _intToBool, toJson: _boolToInt)
  bool get withdrawEnabled;
  @override
  String get currency;
  @override
  @JsonKey(name: 'currency_symbol')
  String get currencySymbol;

  /// Create a copy of SystemConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SystemConfigImplCopyWith<_$SystemConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TransferResult _$TransferResultFromJson(Map<String, dynamic> json) {
  return _TransferResult.fromJson(json);
}

/// @nodoc
mixin _$TransferResult {
  bool get success => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;
  UserInfo? get updatedUserInfo => throw _privateConstructorUsedError;

  /// Serializes this TransferResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TransferResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TransferResultCopyWith<TransferResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransferResultCopyWith<$Res> {
  factory $TransferResultCopyWith(
          TransferResult value, $Res Function(TransferResult) then) =
      _$TransferResultCopyWithImpl<$Res, TransferResult>;
  @useResult
  $Res call({bool success, String? message, UserInfo? updatedUserInfo});

  $UserInfoCopyWith<$Res>? get updatedUserInfo;
}

/// @nodoc
class _$TransferResultCopyWithImpl<$Res, $Val extends TransferResult>
    implements $TransferResultCopyWith<$Res> {
  _$TransferResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TransferResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? message = freezed,
    Object? updatedUserInfo = freezed,
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
      updatedUserInfo: freezed == updatedUserInfo
          ? _value.updatedUserInfo
          : updatedUserInfo // ignore: cast_nullable_to_non_nullable
              as UserInfo?,
    ) as $Val);
  }

  /// Create a copy of TransferResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserInfoCopyWith<$Res>? get updatedUserInfo {
    if (_value.updatedUserInfo == null) {
      return null;
    }

    return $UserInfoCopyWith<$Res>(_value.updatedUserInfo!, (value) {
      return _then(_value.copyWith(updatedUserInfo: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TransferResultImplCopyWith<$Res>
    implements $TransferResultCopyWith<$Res> {
  factory _$$TransferResultImplCopyWith(_$TransferResultImpl value,
          $Res Function(_$TransferResultImpl) then) =
      __$$TransferResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool success, String? message, UserInfo? updatedUserInfo});

  @override
  $UserInfoCopyWith<$Res>? get updatedUserInfo;
}

/// @nodoc
class __$$TransferResultImplCopyWithImpl<$Res>
    extends _$TransferResultCopyWithImpl<$Res, _$TransferResultImpl>
    implements _$$TransferResultImplCopyWith<$Res> {
  __$$TransferResultImplCopyWithImpl(
      _$TransferResultImpl _value, $Res Function(_$TransferResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of TransferResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? message = freezed,
    Object? updatedUserInfo = freezed,
  }) {
    return _then(_$TransferResultImpl(
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedUserInfo: freezed == updatedUserInfo
          ? _value.updatedUserInfo
          : updatedUserInfo // ignore: cast_nullable_to_non_nullable
              as UserInfo?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TransferResultImpl implements _TransferResult {
  const _$TransferResultImpl(
      {required this.success, this.message, this.updatedUserInfo});

  factory _$TransferResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$TransferResultImplFromJson(json);

  @override
  final bool success;
  @override
  final String? message;
  @override
  final UserInfo? updatedUserInfo;

  @override
  String toString() {
    return 'TransferResult(success: $success, message: $message, updatedUserInfo: $updatedUserInfo)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransferResultImpl &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.updatedUserInfo, updatedUserInfo) ||
                other.updatedUserInfo == updatedUserInfo));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, success, message, updatedUserInfo);

  /// Create a copy of TransferResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TransferResultImplCopyWith<_$TransferResultImpl> get copyWith =>
      __$$TransferResultImplCopyWithImpl<_$TransferResultImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TransferResultImplToJson(
      this,
    );
  }
}

abstract class _TransferResult implements TransferResult {
  const factory _TransferResult(
      {required final bool success,
      final String? message,
      final UserInfo? updatedUserInfo}) = _$TransferResultImpl;

  factory _TransferResult.fromJson(Map<String, dynamic> json) =
      _$TransferResultImpl.fromJson;

  @override
  bool get success;
  @override
  String? get message;
  @override
  UserInfo? get updatedUserInfo;

  /// Create a copy of TransferResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TransferResultImplCopyWith<_$TransferResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WithdrawResult _$WithdrawResultFromJson(Map<String, dynamic> json) {
  return _WithdrawResult.fromJson(json);
}

/// @nodoc
mixin _$WithdrawResult {
  bool get success => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;
  String? get withdrawId => throw _privateConstructorUsedError;

  /// Serializes this WithdrawResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WithdrawResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WithdrawResultCopyWith<WithdrawResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WithdrawResultCopyWith<$Res> {
  factory $WithdrawResultCopyWith(
          WithdrawResult value, $Res Function(WithdrawResult) then) =
      _$WithdrawResultCopyWithImpl<$Res, WithdrawResult>;
  @useResult
  $Res call({bool success, String? message, String? withdrawId});
}

/// @nodoc
class _$WithdrawResultCopyWithImpl<$Res, $Val extends WithdrawResult>
    implements $WithdrawResultCopyWith<$Res> {
  _$WithdrawResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WithdrawResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? message = freezed,
    Object? withdrawId = freezed,
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
      withdrawId: freezed == withdrawId
          ? _value.withdrawId
          : withdrawId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WithdrawResultImplCopyWith<$Res>
    implements $WithdrawResultCopyWith<$Res> {
  factory _$$WithdrawResultImplCopyWith(_$WithdrawResultImpl value,
          $Res Function(_$WithdrawResultImpl) then) =
      __$$WithdrawResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool success, String? message, String? withdrawId});
}

/// @nodoc
class __$$WithdrawResultImplCopyWithImpl<$Res>
    extends _$WithdrawResultCopyWithImpl<$Res, _$WithdrawResultImpl>
    implements _$$WithdrawResultImplCopyWith<$Res> {
  __$$WithdrawResultImplCopyWithImpl(
      _$WithdrawResultImpl _value, $Res Function(_$WithdrawResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of WithdrawResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? message = freezed,
    Object? withdrawId = freezed,
  }) {
    return _then(_$WithdrawResultImpl(
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      withdrawId: freezed == withdrawId
          ? _value.withdrawId
          : withdrawId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WithdrawResultImpl implements _WithdrawResult {
  const _$WithdrawResultImpl(
      {required this.success, this.message, this.withdrawId});

  factory _$WithdrawResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$WithdrawResultImplFromJson(json);

  @override
  final bool success;
  @override
  final String? message;
  @override
  final String? withdrawId;

  @override
  String toString() {
    return 'WithdrawResult(success: $success, message: $message, withdrawId: $withdrawId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WithdrawResultImpl &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.withdrawId, withdrawId) ||
                other.withdrawId == withdrawId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, success, message, withdrawId);

  /// Create a copy of WithdrawResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WithdrawResultImplCopyWith<_$WithdrawResultImpl> get copyWith =>
      __$$WithdrawResultImplCopyWithImpl<_$WithdrawResultImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WithdrawResultImplToJson(
      this,
    );
  }
}

abstract class _WithdrawResult implements WithdrawResult {
  const factory _WithdrawResult(
      {required final bool success,
      final String? message,
      final String? withdrawId}) = _$WithdrawResultImpl;

  factory _WithdrawResult.fromJson(Map<String, dynamic> json) =
      _$WithdrawResultImpl.fromJson;

  @override
  bool get success;
  @override
  String? get message;
  @override
  String? get withdrawId;

  /// Create a copy of WithdrawResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WithdrawResultImplCopyWith<_$WithdrawResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CommissionHistoryItem _$CommissionHistoryItemFromJson(
    Map<String, dynamic> json) {
  return _CommissionHistoryItem.fromJson(json);
}

/// @nodoc
mixin _$CommissionHistoryItem {
  int get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'order_amount')
  int get orderAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'trade_no')
  String get tradeNo => throw _privateConstructorUsedError;
  @JsonKey(name: 'get_amount')
  int get getAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  int get createdAt => throw _privateConstructorUsedError;

  /// Serializes this CommissionHistoryItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CommissionHistoryItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CommissionHistoryItemCopyWith<CommissionHistoryItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CommissionHistoryItemCopyWith<$Res> {
  factory $CommissionHistoryItemCopyWith(CommissionHistoryItem value,
          $Res Function(CommissionHistoryItem) then) =
      _$CommissionHistoryItemCopyWithImpl<$Res, CommissionHistoryItem>;
  @useResult
  $Res call(
      {int id,
      @JsonKey(name: 'order_amount') int orderAmount,
      @JsonKey(name: 'trade_no') String tradeNo,
      @JsonKey(name: 'get_amount') int getAmount,
      @JsonKey(name: 'created_at') int createdAt});
}

/// @nodoc
class _$CommissionHistoryItemCopyWithImpl<$Res,
        $Val extends CommissionHistoryItem>
    implements $CommissionHistoryItemCopyWith<$Res> {
  _$CommissionHistoryItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CommissionHistoryItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderAmount = null,
    Object? tradeNo = null,
    Object? getAmount = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      orderAmount: null == orderAmount
          ? _value.orderAmount
          : orderAmount // ignore: cast_nullable_to_non_nullable
              as int,
      tradeNo: null == tradeNo
          ? _value.tradeNo
          : tradeNo // ignore: cast_nullable_to_non_nullable
              as String,
      getAmount: null == getAmount
          ? _value.getAmount
          : getAmount // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CommissionHistoryItemImplCopyWith<$Res>
    implements $CommissionHistoryItemCopyWith<$Res> {
  factory _$$CommissionHistoryItemImplCopyWith(
          _$CommissionHistoryItemImpl value,
          $Res Function(_$CommissionHistoryItemImpl) then) =
      __$$CommissionHistoryItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      @JsonKey(name: 'order_amount') int orderAmount,
      @JsonKey(name: 'trade_no') String tradeNo,
      @JsonKey(name: 'get_amount') int getAmount,
      @JsonKey(name: 'created_at') int createdAt});
}

/// @nodoc
class __$$CommissionHistoryItemImplCopyWithImpl<$Res>
    extends _$CommissionHistoryItemCopyWithImpl<$Res,
        _$CommissionHistoryItemImpl>
    implements _$$CommissionHistoryItemImplCopyWith<$Res> {
  __$$CommissionHistoryItemImplCopyWithImpl(_$CommissionHistoryItemImpl _value,
      $Res Function(_$CommissionHistoryItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of CommissionHistoryItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderAmount = null,
    Object? tradeNo = null,
    Object? getAmount = null,
    Object? createdAt = null,
  }) {
    return _then(_$CommissionHistoryItemImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      orderAmount: null == orderAmount
          ? _value.orderAmount
          : orderAmount // ignore: cast_nullable_to_non_nullable
              as int,
      tradeNo: null == tradeNo
          ? _value.tradeNo
          : tradeNo // ignore: cast_nullable_to_non_nullable
              as String,
      getAmount: null == getAmount
          ? _value.getAmount
          : getAmount // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CommissionHistoryItemImpl implements _CommissionHistoryItem {
  const _$CommissionHistoryItemImpl(
      {required this.id,
      @JsonKey(name: 'order_amount') required this.orderAmount,
      @JsonKey(name: 'trade_no') required this.tradeNo,
      @JsonKey(name: 'get_amount') required this.getAmount,
      @JsonKey(name: 'created_at') required this.createdAt});

  factory _$CommissionHistoryItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$CommissionHistoryItemImplFromJson(json);

  @override
  final int id;
  @override
  @JsonKey(name: 'order_amount')
  final int orderAmount;
  @override
  @JsonKey(name: 'trade_no')
  final String tradeNo;
  @override
  @JsonKey(name: 'get_amount')
  final int getAmount;
  @override
  @JsonKey(name: 'created_at')
  final int createdAt;

  @override
  String toString() {
    return 'CommissionHistoryItem(id: $id, orderAmount: $orderAmount, tradeNo: $tradeNo, getAmount: $getAmount, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CommissionHistoryItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.orderAmount, orderAmount) ||
                other.orderAmount == orderAmount) &&
            (identical(other.tradeNo, tradeNo) || other.tradeNo == tradeNo) &&
            (identical(other.getAmount, getAmount) ||
                other.getAmount == getAmount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, orderAmount, tradeNo, getAmount, createdAt);

  /// Create a copy of CommissionHistoryItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CommissionHistoryItemImplCopyWith<_$CommissionHistoryItemImpl>
      get copyWith => __$$CommissionHistoryItemImplCopyWithImpl<
          _$CommissionHistoryItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CommissionHistoryItemImplToJson(
      this,
    );
  }
}

abstract class _CommissionHistoryItem implements CommissionHistoryItem {
  const factory _CommissionHistoryItem(
          {required final int id,
          @JsonKey(name: 'order_amount') required final int orderAmount,
          @JsonKey(name: 'trade_no') required final String tradeNo,
          @JsonKey(name: 'get_amount') required final int getAmount,
          @JsonKey(name: 'created_at') required final int createdAt}) =
      _$CommissionHistoryItemImpl;

  factory _CommissionHistoryItem.fromJson(Map<String, dynamic> json) =
      _$CommissionHistoryItemImpl.fromJson;

  @override
  int get id;
  @override
  @JsonKey(name: 'order_amount')
  int get orderAmount;
  @override
  @JsonKey(name: 'trade_no')
  String get tradeNo;
  @override
  @JsonKey(name: 'get_amount')
  int get getAmount;
  @override
  @JsonKey(name: 'created_at')
  int get createdAt;

  /// Create a copy of CommissionHistoryItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CommissionHistoryItemImplCopyWith<_$CommissionHistoryItemImpl>
      get copyWith => throw _privateConstructorUsedError;
}
