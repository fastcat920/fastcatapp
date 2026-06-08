// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invite_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

InviteCodeModel _$InviteCodeModelFromJson(Map<String, dynamic> json) {
  return _InviteCodeModel.fromJson(json);
}

/// @nodoc
mixin _$InviteCodeModel {
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

  /// Serializes this InviteCodeModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of InviteCodeModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InviteCodeModelCopyWith<InviteCodeModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InviteCodeModelCopyWith<$Res> {
  factory $InviteCodeModelCopyWith(
          InviteCodeModel value, $Res Function(InviteCodeModel) then) =
      _$InviteCodeModelCopyWithImpl<$Res, InviteCodeModel>;
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
class _$InviteCodeModelCopyWithImpl<$Res, $Val extends InviteCodeModel>
    implements $InviteCodeModelCopyWith<$Res> {
  _$InviteCodeModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of InviteCodeModel
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
abstract class _$$InviteCodeModelImplCopyWith<$Res>
    implements $InviteCodeModelCopyWith<$Res> {
  factory _$$InviteCodeModelImplCopyWith(_$InviteCodeModelImpl value,
          $Res Function(_$InviteCodeModelImpl) then) =
      __$$InviteCodeModelImplCopyWithImpl<$Res>;
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
class __$$InviteCodeModelImplCopyWithImpl<$Res>
    extends _$InviteCodeModelCopyWithImpl<$Res, _$InviteCodeModelImpl>
    implements _$$InviteCodeModelImplCopyWith<$Res> {
  __$$InviteCodeModelImplCopyWithImpl(
      _$InviteCodeModelImpl _value, $Res Function(_$InviteCodeModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of InviteCodeModel
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
    return _then(_$InviteCodeModelImpl(
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
class _$InviteCodeModelImpl extends _InviteCodeModel {
  const _$InviteCodeModelImpl(
      {@JsonKey(name: 'user_id') required this.userId,
      required this.code,
      required this.pv,
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

  factory _$InviteCodeModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$InviteCodeModelImplFromJson(json);

  @override
  @JsonKey(name: 'user_id')
  final int userId;
  @override
  final String code;
  @override
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
    return 'InviteCodeModel(userId: $userId, code: $code, pv: $pv, status: $status, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InviteCodeModelImpl &&
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

  /// Create a copy of InviteCodeModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InviteCodeModelImplCopyWith<_$InviteCodeModelImpl> get copyWith =>
      __$$InviteCodeModelImplCopyWithImpl<_$InviteCodeModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InviteCodeModelImplToJson(
      this,
    );
  }
}

abstract class _InviteCodeModel extends InviteCodeModel {
  const factory _InviteCodeModel(
      {@JsonKey(name: 'user_id') required final int userId,
      required final String code,
      required final int pv,
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
      required final DateTime updatedAt}) = _$InviteCodeModelImpl;
  const _InviteCodeModel._() : super._();

  factory _InviteCodeModel.fromJson(Map<String, dynamic> json) =
      _$InviteCodeModelImpl.fromJson;

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

  /// Create a copy of InviteCodeModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InviteCodeModelImplCopyWith<_$InviteCodeModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

InviteInfoModel _$InviteInfoModelFromJson(Map<String, dynamic> json) {
  return _InviteInfoModel.fromJson(json);
}

/// @nodoc
mixin _$InviteInfoModel {
  List<InviteCodeModel> get codes => throw _privateConstructorUsedError;
  List<int> get stat => throw _privateConstructorUsedError;

  /// Serializes this InviteInfoModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of InviteInfoModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InviteInfoModelCopyWith<InviteInfoModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InviteInfoModelCopyWith<$Res> {
  factory $InviteInfoModelCopyWith(
          InviteInfoModel value, $Res Function(InviteInfoModel) then) =
      _$InviteInfoModelCopyWithImpl<$Res, InviteInfoModel>;
  @useResult
  $Res call({List<InviteCodeModel> codes, List<int> stat});
}

/// @nodoc
class _$InviteInfoModelCopyWithImpl<$Res, $Val extends InviteInfoModel>
    implements $InviteInfoModelCopyWith<$Res> {
  _$InviteInfoModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of InviteInfoModel
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
              as List<InviteCodeModel>,
      stat: null == stat
          ? _value.stat
          : stat // ignore: cast_nullable_to_non_nullable
              as List<int>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$InviteInfoModelImplCopyWith<$Res>
    implements $InviteInfoModelCopyWith<$Res> {
  factory _$$InviteInfoModelImplCopyWith(_$InviteInfoModelImpl value,
          $Res Function(_$InviteInfoModelImpl) then) =
      __$$InviteInfoModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<InviteCodeModel> codes, List<int> stat});
}

/// @nodoc
class __$$InviteInfoModelImplCopyWithImpl<$Res>
    extends _$InviteInfoModelCopyWithImpl<$Res, _$InviteInfoModelImpl>
    implements _$$InviteInfoModelImplCopyWith<$Res> {
  __$$InviteInfoModelImplCopyWithImpl(
      _$InviteInfoModelImpl _value, $Res Function(_$InviteInfoModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of InviteInfoModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? codes = null,
    Object? stat = null,
  }) {
    return _then(_$InviteInfoModelImpl(
      codes: null == codes
          ? _value._codes
          : codes // ignore: cast_nullable_to_non_nullable
              as List<InviteCodeModel>,
      stat: null == stat
          ? _value._stat
          : stat // ignore: cast_nullable_to_non_nullable
              as List<int>,
    ));
  }
}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _$InviteInfoModelImpl extends _InviteInfoModel {
  const _$InviteInfoModelImpl(
      {required final List<InviteCodeModel> codes,
      required final List<int> stat})
      : _codes = codes,
        _stat = stat,
        super._();

  factory _$InviteInfoModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$InviteInfoModelImplFromJson(json);

  final List<InviteCodeModel> _codes;
  @override
  List<InviteCodeModel> get codes {
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
    return 'InviteInfoModel(codes: $codes, stat: $stat)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InviteInfoModelImpl &&
            const DeepCollectionEquality().equals(other._codes, _codes) &&
            const DeepCollectionEquality().equals(other._stat, _stat));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_codes),
      const DeepCollectionEquality().hash(_stat));

  /// Create a copy of InviteInfoModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InviteInfoModelImplCopyWith<_$InviteInfoModelImpl> get copyWith =>
      __$$InviteInfoModelImplCopyWithImpl<_$InviteInfoModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InviteInfoModelImplToJson(
      this,
    );
  }
}

abstract class _InviteInfoModel extends InviteInfoModel {
  const factory _InviteInfoModel(
      {required final List<InviteCodeModel> codes,
      required final List<int> stat}) = _$InviteInfoModelImpl;
  const _InviteInfoModel._() : super._();

  factory _InviteInfoModel.fromJson(Map<String, dynamic> json) =
      _$InviteInfoModelImpl.fromJson;

  @override
  List<InviteCodeModel> get codes;
  @override
  List<int> get stat;

  /// Create a copy of InviteInfoModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InviteInfoModelImplCopyWith<_$InviteInfoModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CommissionDetailModel _$CommissionDetailModelFromJson(
    Map<String, dynamic> json) {
  return _CommissionDetailModel.fromJson(json);
}

/// @nodoc
mixin _$CommissionDetailModel {
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

  /// Serializes this CommissionDetailModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CommissionDetailModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CommissionDetailModelCopyWith<CommissionDetailModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CommissionDetailModelCopyWith<$Res> {
  factory $CommissionDetailModelCopyWith(CommissionDetailModel value,
          $Res Function(CommissionDetailModel) then) =
      _$CommissionDetailModelCopyWithImpl<$Res, CommissionDetailModel>;
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
class _$CommissionDetailModelCopyWithImpl<$Res,
        $Val extends CommissionDetailModel>
    implements $CommissionDetailModelCopyWith<$Res> {
  _$CommissionDetailModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CommissionDetailModel
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
abstract class _$$CommissionDetailModelImplCopyWith<$Res>
    implements $CommissionDetailModelCopyWith<$Res> {
  factory _$$CommissionDetailModelImplCopyWith(
          _$CommissionDetailModelImpl value,
          $Res Function(_$CommissionDetailModelImpl) then) =
      __$$CommissionDetailModelImplCopyWithImpl<$Res>;
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
class __$$CommissionDetailModelImplCopyWithImpl<$Res>
    extends _$CommissionDetailModelCopyWithImpl<$Res,
        _$CommissionDetailModelImpl>
    implements _$$CommissionDetailModelImplCopyWith<$Res> {
  __$$CommissionDetailModelImplCopyWithImpl(_$CommissionDetailModelImpl _value,
      $Res Function(_$CommissionDetailModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of CommissionDetailModel
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
    return _then(_$CommissionDetailModelImpl(
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
class _$CommissionDetailModelImpl extends _CommissionDetailModel {
  const _$CommissionDetailModelImpl(
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

  factory _$CommissionDetailModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$CommissionDetailModelImplFromJson(json);

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
    return 'CommissionDetailModel(id: $id, orderAmount: $orderAmount, tradeNo: $tradeNo, getAmount: $getAmount, commissionStatus: $commissionStatus, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CommissionDetailModelImpl &&
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

  /// Create a copy of CommissionDetailModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CommissionDetailModelImplCopyWith<_$CommissionDetailModelImpl>
      get copyWith => __$$CommissionDetailModelImplCopyWithImpl<
          _$CommissionDetailModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CommissionDetailModelImplToJson(
      this,
    );
  }
}

abstract class _CommissionDetailModel extends CommissionDetailModel {
  const factory _CommissionDetailModel(
      {required final int id,
      @JsonKey(name: 'order_amount') required final int orderAmount,
      @JsonKey(name: 'trade_no') required final String tradeNo,
      @JsonKey(name: 'get_amount') required final int getAmount,
      @JsonKey(name: 'commission_status') final int commissionStatus,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required final DateTime createdAt}) = _$CommissionDetailModelImpl;
  const _CommissionDetailModel._() : super._();

  factory _CommissionDetailModel.fromJson(Map<String, dynamic> json) =
      _$CommissionDetailModelImpl.fromJson;

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

  /// Create a copy of CommissionDetailModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CommissionDetailModelImplCopyWith<_$CommissionDetailModelImpl>
      get copyWith => throw _privateConstructorUsedError;
}
