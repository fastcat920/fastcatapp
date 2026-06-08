// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'xboard_invite_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

InviteCode _$InviteCodeFromJson(Map<String, dynamic> json) {
  return _InviteCode.fromJson(json);
}

/// @nodoc
mixin _$InviteCode {
  @JsonKey(name: 'user_id')
  int get userId => throw _privateConstructorUsedError;
  String get code => throw _privateConstructorUsedError;
  int get pv => throw _privateConstructorUsedError;
  bool get status => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this InviteCode to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of InviteCode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InviteCodeCopyWith<InviteCode> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InviteCodeCopyWith<$Res> {
  factory $InviteCodeCopyWith(
          InviteCode value, $Res Function(InviteCode) then) =
      _$InviteCodeCopyWithImpl<$Res, InviteCode>;
  @useResult
  $Res call(
      {@JsonKey(name: 'user_id') int userId,
      String code,
      int pv,
      bool status,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime updatedAt});
}

/// @nodoc
class _$InviteCodeCopyWithImpl<$Res, $Val extends InviteCode>
    implements $InviteCodeCopyWith<$Res> {
  _$InviteCodeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of InviteCode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? code = null,
    Object? pv = null,
    Object? status = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as int,
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      pv: null == pv
          ? _value.pv
          : pv // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$InviteCodeImplCopyWith<$Res>
    implements $InviteCodeCopyWith<$Res> {
  factory _$$InviteCodeImplCopyWith(
          _$InviteCodeImpl value, $Res Function(_$InviteCodeImpl) then) =
      __$$InviteCodeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'user_id') int userId,
      String code,
      int pv,
      bool status,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime updatedAt});
}

/// @nodoc
class __$$InviteCodeImplCopyWithImpl<$Res>
    extends _$InviteCodeCopyWithImpl<$Res, _$InviteCodeImpl>
    implements _$$InviteCodeImplCopyWith<$Res> {
  __$$InviteCodeImplCopyWithImpl(
      _$InviteCodeImpl _value, $Res Function(_$InviteCodeImpl) _then)
      : super(_value, _then);

  /// Create a copy of InviteCode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? code = null,
    Object? pv = null,
    Object? status = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$InviteCodeImpl(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as int,
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      pv: null == pv
          ? _value.pv
          : pv // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$InviteCodeImpl extends _InviteCode {
  const _$InviteCodeImpl(
      {@JsonKey(name: 'user_id') required this.userId,
      required this.code,
      this.pv = 0,
      required this.status,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required this.createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required this.updatedAt})
      : super._();

  factory _$InviteCodeImpl.fromJson(Map<String, dynamic> json) =>
      _$$InviteCodeImplFromJson(json);

  @override
  @JsonKey(name: 'user_id')
  final int userId;
  @override
  final String code;
  @override
  @JsonKey()
  final int pv;
  @override
  final bool status;
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime createdAt;
  @override
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime updatedAt;

  @override
  String toString() {
    return 'InviteCode(userId: $userId, code: $code, pv: $pv, status: $status, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InviteCodeImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.pv, pv) || other.pv == pv) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, userId, code, pv, status, createdAt, updatedAt);

  /// Create a copy of InviteCode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InviteCodeImplCopyWith<_$InviteCodeImpl> get copyWith =>
      __$$InviteCodeImplCopyWithImpl<_$InviteCodeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InviteCodeImplToJson(
      this,
    );
  }
}

abstract class _InviteCode extends InviteCode {
  const factory _InviteCode(
      {@JsonKey(name: 'user_id') required final int userId,
      required final String code,
      final int pv,
      required final bool status,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required final DateTime createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required final DateTime updatedAt}) = _$InviteCodeImpl;
  const _InviteCode._() : super._();

  factory _InviteCode.fromJson(Map<String, dynamic> json) =
      _$InviteCodeImpl.fromJson;

  @override
  @JsonKey(name: 'user_id')
  int get userId;
  @override
  String get code;
  @override
  int get pv;
  @override
  bool get status;
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get createdAt;
  @override
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get updatedAt;

  /// Create a copy of InviteCode
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InviteCodeImplCopyWith<_$InviteCodeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

InviteInfo _$InviteInfoFromJson(Map<String, dynamic> json) {
  return _InviteInfo.fromJson(json);
}

/// @nodoc
mixin _$InviteInfo {
  List<InviteCode> get codes => throw _privateConstructorUsedError;
  List<int> get stat => throw _privateConstructorUsedError;

  /// Serializes this InviteInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of InviteInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InviteInfoCopyWith<InviteInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InviteInfoCopyWith<$Res> {
  factory $InviteInfoCopyWith(
          InviteInfo value, $Res Function(InviteInfo) then) =
      _$InviteInfoCopyWithImpl<$Res, InviteInfo>;
  @useResult
  $Res call({List<InviteCode> codes, List<int> stat});
}

/// @nodoc
class _$InviteInfoCopyWithImpl<$Res, $Val extends InviteInfo>
    implements $InviteInfoCopyWith<$Res> {
  _$InviteInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of InviteInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? codes = null,
    Object? stat = null,
  }) {
    return _then(_value.copyWith(
      codes: null == codes
          ? _value.codes
          : codes // ignore: cast_nullable_to_non_nullable
              as List<InviteCode>,
      stat: null == stat
          ? _value.stat
          : stat // ignore: cast_nullable_to_non_nullable
              as List<int>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$InviteInfoImplCopyWith<$Res>
    implements $InviteInfoCopyWith<$Res> {
  factory _$$InviteInfoImplCopyWith(
          _$InviteInfoImpl value, $Res Function(_$InviteInfoImpl) then) =
      __$$InviteInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<InviteCode> codes, List<int> stat});
}

/// @nodoc
class __$$InviteInfoImplCopyWithImpl<$Res>
    extends _$InviteInfoCopyWithImpl<$Res, _$InviteInfoImpl>
    implements _$$InviteInfoImplCopyWith<$Res> {
  __$$InviteInfoImplCopyWithImpl(
      _$InviteInfoImpl _value, $Res Function(_$InviteInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of InviteInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? codes = null,
    Object? stat = null,
  }) {
    return _then(_$InviteInfoImpl(
      codes: null == codes
          ? _value._codes
          : codes // ignore: cast_nullable_to_non_nullable
              as List<InviteCode>,
      stat: null == stat
          ? _value._stat
          : stat // ignore: cast_nullable_to_non_nullable
              as List<int>,
    ));
  }
}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _$InviteInfoImpl extends _InviteInfo {
  const _$InviteInfoImpl(
      {required final List<InviteCode> codes, required final List<int> stat})
      : _codes = codes,
        _stat = stat,
        super._();

  factory _$InviteInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$InviteInfoImplFromJson(json);

  final List<InviteCode> _codes;
  @override
  List<InviteCode> get codes {
    if (_codes is EqualUnmodifiableListView) return _codes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_codes);
  }

  final List<int> _stat;
  @override
  List<int> get stat {
    if (_stat is EqualUnmodifiableListView) return _stat;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_stat);
  }

  @override
  String toString() {
    return 'InviteInfo(codes: $codes, stat: $stat)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InviteInfoImpl &&
            const DeepCollectionEquality().equals(other._codes, _codes) &&
            const DeepCollectionEquality().equals(other._stat, _stat));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_codes),
      const DeepCollectionEquality().hash(_stat));

  /// Create a copy of InviteInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InviteInfoImplCopyWith<_$InviteInfoImpl> get copyWith =>
      __$$InviteInfoImplCopyWithImpl<_$InviteInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InviteInfoImplToJson(
      this,
    );
  }
}

abstract class _InviteInfo extends InviteInfo {
  const factory _InviteInfo(
      {required final List<InviteCode> codes,
      required final List<int> stat}) = _$InviteInfoImpl;
  const _InviteInfo._() : super._();

  factory _InviteInfo.fromJson(Map<String, dynamic> json) =
      _$InviteInfoImpl.fromJson;

  @override
  List<InviteCode> get codes;
  @override
  List<int> get stat;

  /// Create a copy of InviteInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InviteInfoImplCopyWith<_$InviteInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CommissionDetail _$CommissionDetailFromJson(Map<String, dynamic> json) {
  return _CommissionDetail.fromJson(json);
}

/// @nodoc
mixin _$CommissionDetail {
  int get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'order_amount')
  int get orderAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'trade_no')
  String get tradeNo => throw _privateConstructorUsedError;
  @JsonKey(name: 'get_amount')
  int get getAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'commission_status')
  int get commissionStatus => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this CommissionDetail to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CommissionDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CommissionDetailCopyWith<CommissionDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CommissionDetailCopyWith<$Res> {
  factory $CommissionDetailCopyWith(
          CommissionDetail value, $Res Function(CommissionDetail) then) =
      _$CommissionDetailCopyWithImpl<$Res, CommissionDetail>;
  @useResult
  $Res call(
      {int id,
      @JsonKey(name: 'order_amount') int orderAmount,
      @JsonKey(name: 'trade_no') String tradeNo,
      @JsonKey(name: 'get_amount') int getAmount,
      @JsonKey(name: 'commission_status') int commissionStatus,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime createdAt});
}

/// @nodoc
class _$CommissionDetailCopyWithImpl<$Res, $Val extends CommissionDetail>
    implements $CommissionDetailCopyWith<$Res> {
  _$CommissionDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CommissionDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderAmount = null,
    Object? tradeNo = null,
    Object? getAmount = null,
    Object? commissionStatus = null,
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
      commissionStatus: null == commissionStatus
          ? _value.commissionStatus
          : commissionStatus // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CommissionDetailImplCopyWith<$Res>
    implements $CommissionDetailCopyWith<$Res> {
  factory _$$CommissionDetailImplCopyWith(_$CommissionDetailImpl value,
          $Res Function(_$CommissionDetailImpl) then) =
      __$$CommissionDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      @JsonKey(name: 'order_amount') int orderAmount,
      @JsonKey(name: 'trade_no') String tradeNo,
      @JsonKey(name: 'get_amount') int getAmount,
      @JsonKey(name: 'commission_status') int commissionStatus,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      DateTime createdAt});
}

/// @nodoc
class __$$CommissionDetailImplCopyWithImpl<$Res>
    extends _$CommissionDetailCopyWithImpl<$Res, _$CommissionDetailImpl>
    implements _$$CommissionDetailImplCopyWith<$Res> {
  __$$CommissionDetailImplCopyWithImpl(_$CommissionDetailImpl _value,
      $Res Function(_$CommissionDetailImpl) _then)
      : super(_value, _then);

  /// Create a copy of CommissionDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderAmount = null,
    Object? tradeNo = null,
    Object? getAmount = null,
    Object? commissionStatus = null,
    Object? createdAt = null,
  }) {
    return _then(_$CommissionDetailImpl(
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
      commissionStatus: null == commissionStatus
          ? _value.commissionStatus
          : commissionStatus // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CommissionDetailImpl extends _CommissionDetail {
  const _$CommissionDetailImpl(
      {required this.id,
      @JsonKey(name: 'order_amount') required this.orderAmount,
      @JsonKey(name: 'trade_no') required this.tradeNo,
      @JsonKey(name: 'get_amount') required this.getAmount,
      @JsonKey(name: 'commission_status') this.commissionStatus = 2,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required this.createdAt})
      : super._();

  factory _$CommissionDetailImpl.fromJson(Map<String, dynamic> json) =>
      _$$CommissionDetailImplFromJson(json);

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
  @JsonKey(name: 'commission_status')
  final int commissionStatus;
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final DateTime createdAt;

  @override
  String toString() {
    return 'CommissionDetail(id: $id, orderAmount: $orderAmount, tradeNo: $tradeNo, getAmount: $getAmount, commissionStatus: $commissionStatus, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CommissionDetailImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.orderAmount, orderAmount) ||
                other.orderAmount == orderAmount) &&
            (identical(other.tradeNo, tradeNo) || other.tradeNo == tradeNo) &&
            (identical(other.getAmount, getAmount) ||
                other.getAmount == getAmount) &&
            (identical(other.commissionStatus, commissionStatus) ||
                other.commissionStatus == commissionStatus) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, orderAmount, tradeNo,
      getAmount, commissionStatus, createdAt);

  /// Create a copy of CommissionDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CommissionDetailImplCopyWith<_$CommissionDetailImpl> get copyWith =>
      __$$CommissionDetailImplCopyWithImpl<_$CommissionDetailImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CommissionDetailImplToJson(
      this,
    );
  }
}

abstract class _CommissionDetail extends CommissionDetail {
  const factory _CommissionDetail(
      {required final int id,
      @JsonKey(name: 'order_amount') required final int orderAmount,
      @JsonKey(name: 'trade_no') required final String tradeNo,
      @JsonKey(name: 'get_amount') required final int getAmount,
      @JsonKey(name: 'commission_status') final int commissionStatus,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required final DateTime createdAt}) = _$CommissionDetailImpl;
  const _CommissionDetail._() : super._();

  factory _CommissionDetail.fromJson(Map<String, dynamic> json) =
      _$CommissionDetailImpl.fromJson;

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
  @JsonKey(name: 'commission_status')
  int get commissionStatus;
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  DateTime get createdAt;

  /// Create a copy of CommissionDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CommissionDetailImplCopyWith<_$CommissionDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
