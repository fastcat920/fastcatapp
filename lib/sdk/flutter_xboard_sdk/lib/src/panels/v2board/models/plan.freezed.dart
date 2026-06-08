// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Plan _$PlanFromJson(Map<String, dynamic> json) {
  return _Plan.fromJson(json);
}

/// @nodoc
mixin _$Plan {
  int get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'group_id')
  int? get groupId => throw _privateConstructorUsedError;
  @JsonKey(name: 'transfer_enable')
  int? get transferEnable => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  int? get show => throw _privateConstructorUsedError;
  int? get sort => throw _privateConstructorUsedError;
  int? get renew => throw _privateConstructorUsedError;
  String? get content => throw _privateConstructorUsedError;
  @JsonKey(name: 'month_price')
  int? get monthPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'quarter_price')
  int? get quarterPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'half_year_price')
  int? get halfYearPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'year_price')
  int? get yearPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'two_year_price')
  int? get twoYearPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'three_year_price')
  int? get threeYearPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'onetime_price')
  int? get onetimePrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'reset_price')
  int? get resetPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'reset_traffic_method')
  int? get resetTrafficMethod => throw _privateConstructorUsedError;
  @JsonKey(name: 'capacity_limit')
  int? get capacityLimit => throw _privateConstructorUsedError;
  @JsonKey(name: 'speed_limit')
  int? get speedLimit => throw _privateConstructorUsedError;
  @JsonKey(name: 'device_limit')
  int? get deviceLimit => throw _privateConstructorUsedError;

  /// Serializes this Plan to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanCopyWith<Plan> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanCopyWith<$Res> {
  factory $PlanCopyWith(Plan value, $Res Function(Plan) then) =
      _$PlanCopyWithImpl<$Res, Plan>;
  @useResult
  $Res call(
      {int id,
      @JsonKey(name: 'group_id') int? groupId,
      @JsonKey(name: 'transfer_enable') int? transferEnable,
      String? name,
      int? show,
      int? sort,
      int? renew,
      String? content,
      @JsonKey(name: 'month_price') int? monthPrice,
      @JsonKey(name: 'quarter_price') int? quarterPrice,
      @JsonKey(name: 'half_year_price') int? halfYearPrice,
      @JsonKey(name: 'year_price') int? yearPrice,
      @JsonKey(name: 'two_year_price') int? twoYearPrice,
      @JsonKey(name: 'three_year_price') int? threeYearPrice,
      @JsonKey(name: 'onetime_price') int? onetimePrice,
      @JsonKey(name: 'reset_price') int? resetPrice,
      @JsonKey(name: 'reset_traffic_method') int? resetTrafficMethod,
      @JsonKey(name: 'capacity_limit') int? capacityLimit,
      @JsonKey(name: 'speed_limit') int? speedLimit,
      @JsonKey(name: 'device_limit') int? deviceLimit});
}

/// @nodoc
class _$PlanCopyWithImpl<$Res, $Val extends Plan>
    implements $PlanCopyWith<$Res> {
  _$PlanCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = freezed,
    Object? transferEnable = freezed,
    Object? name = freezed,
    Object? show = freezed,
    Object? sort = freezed,
    Object? renew = freezed,
    Object? content = freezed,
    Object? monthPrice = freezed,
    Object? quarterPrice = freezed,
    Object? halfYearPrice = freezed,
    Object? yearPrice = freezed,
    Object? twoYearPrice = freezed,
    Object? threeYearPrice = freezed,
    Object? onetimePrice = freezed,
    Object? resetPrice = freezed,
    Object? resetTrafficMethod = freezed,
    Object? capacityLimit = freezed,
    Object? speedLimit = freezed,
    Object? deviceLimit = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      groupId: freezed == groupId
          ? _value.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as int?,
      transferEnable: freezed == transferEnable
          ? _value.transferEnable
          : transferEnable // ignore: cast_nullable_to_non_nullable
              as int?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      show: freezed == show
          ? _value.show
          : show // ignore: cast_nullable_to_non_nullable
              as int?,
      sort: freezed == sort
          ? _value.sort
          : sort // ignore: cast_nullable_to_non_nullable
              as int?,
      renew: freezed == renew
          ? _value.renew
          : renew // ignore: cast_nullable_to_non_nullable
              as int?,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
      monthPrice: freezed == monthPrice
          ? _value.monthPrice
          : monthPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      quarterPrice: freezed == quarterPrice
          ? _value.quarterPrice
          : quarterPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      halfYearPrice: freezed == halfYearPrice
          ? _value.halfYearPrice
          : halfYearPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      yearPrice: freezed == yearPrice
          ? _value.yearPrice
          : yearPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      twoYearPrice: freezed == twoYearPrice
          ? _value.twoYearPrice
          : twoYearPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      threeYearPrice: freezed == threeYearPrice
          ? _value.threeYearPrice
          : threeYearPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      onetimePrice: freezed == onetimePrice
          ? _value.onetimePrice
          : onetimePrice // ignore: cast_nullable_to_non_nullable
              as int?,
      resetPrice: freezed == resetPrice
          ? _value.resetPrice
          : resetPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      resetTrafficMethod: freezed == resetTrafficMethod
          ? _value.resetTrafficMethod
          : resetTrafficMethod // ignore: cast_nullable_to_non_nullable
              as int?,
      capacityLimit: freezed == capacityLimit
          ? _value.capacityLimit
          : capacityLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      speedLimit: freezed == speedLimit
          ? _value.speedLimit
          : speedLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      deviceLimit: freezed == deviceLimit
          ? _value.deviceLimit
          : deviceLimit // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlanImplCopyWith<$Res> implements $PlanCopyWith<$Res> {
  factory _$$PlanImplCopyWith(
          _$PlanImpl value, $Res Function(_$PlanImpl) then) =
      __$$PlanImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      @JsonKey(name: 'group_id') int? groupId,
      @JsonKey(name: 'transfer_enable') int? transferEnable,
      String? name,
      int? show,
      int? sort,
      int? renew,
      String? content,
      @JsonKey(name: 'month_price') int? monthPrice,
      @JsonKey(name: 'quarter_price') int? quarterPrice,
      @JsonKey(name: 'half_year_price') int? halfYearPrice,
      @JsonKey(name: 'year_price') int? yearPrice,
      @JsonKey(name: 'two_year_price') int? twoYearPrice,
      @JsonKey(name: 'three_year_price') int? threeYearPrice,
      @JsonKey(name: 'onetime_price') int? onetimePrice,
      @JsonKey(name: 'reset_price') int? resetPrice,
      @JsonKey(name: 'reset_traffic_method') int? resetTrafficMethod,
      @JsonKey(name: 'capacity_limit') int? capacityLimit,
      @JsonKey(name: 'speed_limit') int? speedLimit,
      @JsonKey(name: 'device_limit') int? deviceLimit});
}

/// @nodoc
class __$$PlanImplCopyWithImpl<$Res>
    extends _$PlanCopyWithImpl<$Res, _$PlanImpl>
    implements _$$PlanImplCopyWith<$Res> {
  __$$PlanImplCopyWithImpl(_$PlanImpl _value, $Res Function(_$PlanImpl) _then)
      : super(_value, _then);

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = freezed,
    Object? transferEnable = freezed,
    Object? name = freezed,
    Object? show = freezed,
    Object? sort = freezed,
    Object? renew = freezed,
    Object? content = freezed,
    Object? monthPrice = freezed,
    Object? quarterPrice = freezed,
    Object? halfYearPrice = freezed,
    Object? yearPrice = freezed,
    Object? twoYearPrice = freezed,
    Object? threeYearPrice = freezed,
    Object? onetimePrice = freezed,
    Object? resetPrice = freezed,
    Object? resetTrafficMethod = freezed,
    Object? capacityLimit = freezed,
    Object? speedLimit = freezed,
    Object? deviceLimit = freezed,
  }) {
    return _then(_$PlanImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      groupId: freezed == groupId
          ? _value.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as int?,
      transferEnable: freezed == transferEnable
          ? _value.transferEnable
          : transferEnable // ignore: cast_nullable_to_non_nullable
              as int?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      show: freezed == show
          ? _value.show
          : show // ignore: cast_nullable_to_non_nullable
              as int?,
      sort: freezed == sort
          ? _value.sort
          : sort // ignore: cast_nullable_to_non_nullable
              as int?,
      renew: freezed == renew
          ? _value.renew
          : renew // ignore: cast_nullable_to_non_nullable
              as int?,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
      monthPrice: freezed == monthPrice
          ? _value.monthPrice
          : monthPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      quarterPrice: freezed == quarterPrice
          ? _value.quarterPrice
          : quarterPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      halfYearPrice: freezed == halfYearPrice
          ? _value.halfYearPrice
          : halfYearPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      yearPrice: freezed == yearPrice
          ? _value.yearPrice
          : yearPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      twoYearPrice: freezed == twoYearPrice
          ? _value.twoYearPrice
          : twoYearPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      threeYearPrice: freezed == threeYearPrice
          ? _value.threeYearPrice
          : threeYearPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      onetimePrice: freezed == onetimePrice
          ? _value.onetimePrice
          : onetimePrice // ignore: cast_nullable_to_non_nullable
              as int?,
      resetPrice: freezed == resetPrice
          ? _value.resetPrice
          : resetPrice // ignore: cast_nullable_to_non_nullable
              as int?,
      resetTrafficMethod: freezed == resetTrafficMethod
          ? _value.resetTrafficMethod
          : resetTrafficMethod // ignore: cast_nullable_to_non_nullable
              as int?,
      capacityLimit: freezed == capacityLimit
          ? _value.capacityLimit
          : capacityLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      speedLimit: freezed == speedLimit
          ? _value.speedLimit
          : speedLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      deviceLimit: freezed == deviceLimit
          ? _value.deviceLimit
          : deviceLimit // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlanImpl extends _Plan {
  const _$PlanImpl(
      {required this.id,
      @JsonKey(name: 'group_id') this.groupId,
      @JsonKey(name: 'transfer_enable') this.transferEnable,
      this.name,
      this.show,
      this.sort,
      this.renew,
      this.content,
      @JsonKey(name: 'month_price') this.monthPrice,
      @JsonKey(name: 'quarter_price') this.quarterPrice,
      @JsonKey(name: 'half_year_price') this.halfYearPrice,
      @JsonKey(name: 'year_price') this.yearPrice,
      @JsonKey(name: 'two_year_price') this.twoYearPrice,
      @JsonKey(name: 'three_year_price') this.threeYearPrice,
      @JsonKey(name: 'onetime_price') this.onetimePrice,
      @JsonKey(name: 'reset_price') this.resetPrice,
      @JsonKey(name: 'reset_traffic_method') this.resetTrafficMethod,
      @JsonKey(name: 'capacity_limit') this.capacityLimit,
      @JsonKey(name: 'speed_limit') this.speedLimit,
      @JsonKey(name: 'device_limit') this.deviceLimit})
      : super._();

  factory _$PlanImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanImplFromJson(json);

  @override
  final int id;
  @override
  @JsonKey(name: 'group_id')
  final int? groupId;
  @override
  @JsonKey(name: 'transfer_enable')
  final int? transferEnable;
  @override
  final String? name;
  @override
  final int? show;
  @override
  final int? sort;
  @override
  final int? renew;
  @override
  final String? content;
  @override
  @JsonKey(name: 'month_price')
  final int? monthPrice;
  @override
  @JsonKey(name: 'quarter_price')
  final int? quarterPrice;
  @override
  @JsonKey(name: 'half_year_price')
  final int? halfYearPrice;
  @override
  @JsonKey(name: 'year_price')
  final int? yearPrice;
  @override
  @JsonKey(name: 'two_year_price')
  final int? twoYearPrice;
  @override
  @JsonKey(name: 'three_year_price')
  final int? threeYearPrice;
  @override
  @JsonKey(name: 'onetime_price')
  final int? onetimePrice;
  @override
  @JsonKey(name: 'reset_price')
  final int? resetPrice;
  @override
  @JsonKey(name: 'reset_traffic_method')
  final int? resetTrafficMethod;
  @override
  @JsonKey(name: 'capacity_limit')
  final int? capacityLimit;
  @override
  @JsonKey(name: 'speed_limit')
  final int? speedLimit;
  @override
  @JsonKey(name: 'device_limit')
  final int? deviceLimit;

  @override
  String toString() {
    return 'Plan(id: $id, groupId: $groupId, transferEnable: $transferEnable, name: $name, show: $show, sort: $sort, renew: $renew, content: $content, monthPrice: $monthPrice, quarterPrice: $quarterPrice, halfYearPrice: $halfYearPrice, yearPrice: $yearPrice, twoYearPrice: $twoYearPrice, threeYearPrice: $threeYearPrice, onetimePrice: $onetimePrice, resetPrice: $resetPrice, resetTrafficMethod: $resetTrafficMethod, capacityLimit: $capacityLimit, speedLimit: $speedLimit, deviceLimit: $deviceLimit)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.transferEnable, transferEnable) ||
                other.transferEnable == transferEnable) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.show, show) || other.show == show) &&
            (identical(other.sort, sort) || other.sort == sort) &&
            (identical(other.renew, renew) || other.renew == renew) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.monthPrice, monthPrice) ||
                other.monthPrice == monthPrice) &&
            (identical(other.quarterPrice, quarterPrice) ||
                other.quarterPrice == quarterPrice) &&
            (identical(other.halfYearPrice, halfYearPrice) ||
                other.halfYearPrice == halfYearPrice) &&
            (identical(other.yearPrice, yearPrice) ||
                other.yearPrice == yearPrice) &&
            (identical(other.twoYearPrice, twoYearPrice) ||
                other.twoYearPrice == twoYearPrice) &&
            (identical(other.threeYearPrice, threeYearPrice) ||
                other.threeYearPrice == threeYearPrice) &&
            (identical(other.onetimePrice, onetimePrice) ||
                other.onetimePrice == onetimePrice) &&
            (identical(other.resetPrice, resetPrice) ||
                other.resetPrice == resetPrice) &&
            (identical(other.resetTrafficMethod, resetTrafficMethod) ||
                other.resetTrafficMethod == resetTrafficMethod) &&
            (identical(other.capacityLimit, capacityLimit) ||
                other.capacityLimit == capacityLimit) &&
            (identical(other.speedLimit, speedLimit) ||
                other.speedLimit == speedLimit) &&
            (identical(other.deviceLimit, deviceLimit) ||
                other.deviceLimit == deviceLimit));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        groupId,
        transferEnable,
        name,
        show,
        sort,
        renew,
        content,
        monthPrice,
        quarterPrice,
        halfYearPrice,
        yearPrice,
        twoYearPrice,
        threeYearPrice,
        onetimePrice,
        resetPrice,
        resetTrafficMethod,
        capacityLimit,
        speedLimit,
        deviceLimit
      ]);

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanImplCopyWith<_$PlanImpl> get copyWith =>
      __$$PlanImplCopyWithImpl<_$PlanImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlanImplToJson(
      this,
    );
  }
}

abstract class _Plan extends Plan {
  const factory _Plan(
      {required final int id,
      @JsonKey(name: 'group_id') final int? groupId,
      @JsonKey(name: 'transfer_enable') final int? transferEnable,
      final String? name,
      final int? show,
      final int? sort,
      final int? renew,
      final String? content,
      @JsonKey(name: 'month_price') final int? monthPrice,
      @JsonKey(name: 'quarter_price') final int? quarterPrice,
      @JsonKey(name: 'half_year_price') final int? halfYearPrice,
      @JsonKey(name: 'year_price') final int? yearPrice,
      @JsonKey(name: 'two_year_price') final int? twoYearPrice,
      @JsonKey(name: 'three_year_price') final int? threeYearPrice,
      @JsonKey(name: 'onetime_price') final int? onetimePrice,
      @JsonKey(name: 'reset_price') final int? resetPrice,
      @JsonKey(name: 'reset_traffic_method') final int? resetTrafficMethod,
      @JsonKey(name: 'capacity_limit') final int? capacityLimit,
      @JsonKey(name: 'speed_limit') final int? speedLimit,
      @JsonKey(name: 'device_limit') final int? deviceLimit}) = _$PlanImpl;
  const _Plan._() : super._();

  factory _Plan.fromJson(Map<String, dynamic> json) = _$PlanImpl.fromJson;

  @override
  int get id;
  @override
  @JsonKey(name: 'group_id')
  int? get groupId;
  @override
  @JsonKey(name: 'transfer_enable')
  int? get transferEnable;
  @override
  String? get name;
  @override
  int? get show;
  @override
  int? get sort;
  @override
  int? get renew;
  @override
  String? get content;
  @override
  @JsonKey(name: 'month_price')
  int? get monthPrice;
  @override
  @JsonKey(name: 'quarter_price')
  int? get quarterPrice;
  @override
  @JsonKey(name: 'half_year_price')
  int? get halfYearPrice;
  @override
  @JsonKey(name: 'year_price')
  int? get yearPrice;
  @override
  @JsonKey(name: 'two_year_price')
  int? get twoYearPrice;
  @override
  @JsonKey(name: 'three_year_price')
  int? get threeYearPrice;
  @override
  @JsonKey(name: 'onetime_price')
  int? get onetimePrice;
  @override
  @JsonKey(name: 'reset_price')
  int? get resetPrice;
  @override
  @JsonKey(name: 'reset_traffic_method')
  int? get resetTrafficMethod;
  @override
  @JsonKey(name: 'capacity_limit')
  int? get capacityLimit;
  @override
  @JsonKey(name: 'speed_limit')
  int? get speedLimit;
  @override
  @JsonKey(name: 'device_limit')
  int? get deviceLimit;

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanImplCopyWith<_$PlanImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
