// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'xboard_plan_models.dart';

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
  int get groupId => throw _privateConstructorUsedError;
  @JsonKey(name: 'transfer_enable')
  double get transferEnable => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  List<String>? get tags => throw _privateConstructorUsedError;
  @JsonKey(name: 'speed_limit')
  int? get speedLimit => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool get show => throw _privateConstructorUsedError;
  String? get content => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'onetime_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get onetimePrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'month_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get monthPrice => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'quarter_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get quarterPrice => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'half_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get halfYearPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get yearPrice => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'two_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get twoYearPrice => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'three_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get threeYearPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'reset_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get resetPrice => throw _privateConstructorUsedError;
  @JsonKey(name: 'capacity_limit')
  dynamic get capacityLimit => throw _privateConstructorUsedError;
  @JsonKey(name: 'device_limit')
  int? get deviceLimit => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt, defaultValue: true)
  bool? get sell => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool get renew => throw _privateConstructorUsedError;
  @JsonKey(name: 'reset_traffic_method')
  int? get resetTrafficMethod => throw _privateConstructorUsedError;
  int? get sort => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  int? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  int? get updatedAt => throw _privateConstructorUsedError;

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
      @JsonKey(name: 'group_id') int groupId,
      @JsonKey(name: 'transfer_enable') double transferEnable,
      String name,
      List<String>? tags,
      @JsonKey(name: 'speed_limit') int? speedLimit,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) bool show,
      String? content,
      @JsonKey(
          name: 'onetime_price', fromJson: _priceFromJson, toJson: _priceToJson)
      double? onetimePrice,
      @JsonKey(
          name: 'month_price', fromJson: _priceFromJson, toJson: _priceToJson)
      double? monthPrice,
      @JsonKey(
          name: 'quarter_price', fromJson: _priceFromJson, toJson: _priceToJson)
      double? quarterPrice,
      @JsonKey(
          name: 'half_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      double? halfYearPrice,
      @JsonKey(
          name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
      double? yearPrice,
      @JsonKey(
          name: 'two_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      double? twoYearPrice,
      @JsonKey(
          name: 'three_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      double? threeYearPrice,
      @JsonKey(
          name: 'reset_price', fromJson: _priceFromJson, toJson: _priceToJson)
      double? resetPrice,
      @JsonKey(name: 'capacity_limit') dynamic capacityLimit,
      @JsonKey(name: 'device_limit') int? deviceLimit,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt, defaultValue: true)
      bool? sell,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) bool renew,
      @JsonKey(name: 'reset_traffic_method') int? resetTrafficMethod,
      int? sort,
      @JsonKey(name: 'created_at') int? createdAt,
      @JsonKey(name: 'updated_at') int? updatedAt});
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
    Object? groupId = null,
    Object? transferEnable = null,
    Object? name = null,
    Object? tags = freezed,
    Object? speedLimit = freezed,
    Object? show = null,
    Object? content = freezed,
    Object? onetimePrice = freezed,
    Object? monthPrice = freezed,
    Object? quarterPrice = freezed,
    Object? halfYearPrice = freezed,
    Object? yearPrice = freezed,
    Object? twoYearPrice = freezed,
    Object? threeYearPrice = freezed,
    Object? resetPrice = freezed,
    Object? capacityLimit = freezed,
    Object? deviceLimit = freezed,
    Object? sell = freezed,
    Object? renew = null,
    Object? resetTrafficMethod = freezed,
    Object? sort = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      groupId: null == groupId
          ? _value.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as int,
      transferEnable: null == transferEnable
          ? _value.transferEnable
          : transferEnable // ignore: cast_nullable_to_non_nullable
              as double,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      tags: freezed == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      speedLimit: freezed == speedLimit
          ? _value.speedLimit
          : speedLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      show: null == show
          ? _value.show
          : show // ignore: cast_nullable_to_non_nullable
              as bool,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
      onetimePrice: freezed == onetimePrice
          ? _value.onetimePrice
          : onetimePrice // ignore: cast_nullable_to_non_nullable
              as double?,
      monthPrice: freezed == monthPrice
          ? _value.monthPrice
          : monthPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      quarterPrice: freezed == quarterPrice
          ? _value.quarterPrice
          : quarterPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      halfYearPrice: freezed == halfYearPrice
          ? _value.halfYearPrice
          : halfYearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      yearPrice: freezed == yearPrice
          ? _value.yearPrice
          : yearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      twoYearPrice: freezed == twoYearPrice
          ? _value.twoYearPrice
          : twoYearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      threeYearPrice: freezed == threeYearPrice
          ? _value.threeYearPrice
          : threeYearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      resetPrice: freezed == resetPrice
          ? _value.resetPrice
          : resetPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      capacityLimit: freezed == capacityLimit
          ? _value.capacityLimit
          : capacityLimit // ignore: cast_nullable_to_non_nullable
              as dynamic,
      deviceLimit: freezed == deviceLimit
          ? _value.deviceLimit
          : deviceLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      sell: freezed == sell
          ? _value.sell
          : sell // ignore: cast_nullable_to_non_nullable
              as bool?,
      renew: null == renew
          ? _value.renew
          : renew // ignore: cast_nullable_to_non_nullable
              as bool,
      resetTrafficMethod: freezed == resetTrafficMethod
          ? _value.resetTrafficMethod
          : resetTrafficMethod // ignore: cast_nullable_to_non_nullable
              as int?,
      sort: freezed == sort
          ? _value.sort
          : sort // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
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
      @JsonKey(name: 'group_id') int groupId,
      @JsonKey(name: 'transfer_enable') double transferEnable,
      String name,
      List<String>? tags,
      @JsonKey(name: 'speed_limit') int? speedLimit,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) bool show,
      String? content,
      @JsonKey(
          name: 'onetime_price', fromJson: _priceFromJson, toJson: _priceToJson)
      double? onetimePrice,
      @JsonKey(
          name: 'month_price', fromJson: _priceFromJson, toJson: _priceToJson)
      double? monthPrice,
      @JsonKey(
          name: 'quarter_price', fromJson: _priceFromJson, toJson: _priceToJson)
      double? quarterPrice,
      @JsonKey(
          name: 'half_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      double? halfYearPrice,
      @JsonKey(
          name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
      double? yearPrice,
      @JsonKey(
          name: 'two_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      double? twoYearPrice,
      @JsonKey(
          name: 'three_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      double? threeYearPrice,
      @JsonKey(
          name: 'reset_price', fromJson: _priceFromJson, toJson: _priceToJson)
      double? resetPrice,
      @JsonKey(name: 'capacity_limit') dynamic capacityLimit,
      @JsonKey(name: 'device_limit') int? deviceLimit,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt, defaultValue: true)
      bool? sell,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) bool renew,
      @JsonKey(name: 'reset_traffic_method') int? resetTrafficMethod,
      int? sort,
      @JsonKey(name: 'created_at') int? createdAt,
      @JsonKey(name: 'updated_at') int? updatedAt});
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
    Object? groupId = null,
    Object? transferEnable = null,
    Object? name = null,
    Object? tags = freezed,
    Object? speedLimit = freezed,
    Object? show = null,
    Object? content = freezed,
    Object? onetimePrice = freezed,
    Object? monthPrice = freezed,
    Object? quarterPrice = freezed,
    Object? halfYearPrice = freezed,
    Object? yearPrice = freezed,
    Object? twoYearPrice = freezed,
    Object? threeYearPrice = freezed,
    Object? resetPrice = freezed,
    Object? capacityLimit = freezed,
    Object? deviceLimit = freezed,
    Object? sell = freezed,
    Object? renew = null,
    Object? resetTrafficMethod = freezed,
    Object? sort = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$PlanImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      groupId: null == groupId
          ? _value.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as int,
      transferEnable: null == transferEnable
          ? _value.transferEnable
          : transferEnable // ignore: cast_nullable_to_non_nullable
              as double,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      tags: freezed == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      speedLimit: freezed == speedLimit
          ? _value.speedLimit
          : speedLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      show: null == show
          ? _value.show
          : show // ignore: cast_nullable_to_non_nullable
              as bool,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
      onetimePrice: freezed == onetimePrice
          ? _value.onetimePrice
          : onetimePrice // ignore: cast_nullable_to_non_nullable
              as double?,
      monthPrice: freezed == monthPrice
          ? _value.monthPrice
          : monthPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      quarterPrice: freezed == quarterPrice
          ? _value.quarterPrice
          : quarterPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      halfYearPrice: freezed == halfYearPrice
          ? _value.halfYearPrice
          : halfYearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      yearPrice: freezed == yearPrice
          ? _value.yearPrice
          : yearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      twoYearPrice: freezed == twoYearPrice
          ? _value.twoYearPrice
          : twoYearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      threeYearPrice: freezed == threeYearPrice
          ? _value.threeYearPrice
          : threeYearPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      resetPrice: freezed == resetPrice
          ? _value.resetPrice
          : resetPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      capacityLimit: freezed == capacityLimit
          ? _value.capacityLimit
          : capacityLimit // ignore: cast_nullable_to_non_nullable
              as dynamic,
      deviceLimit: freezed == deviceLimit
          ? _value.deviceLimit
          : deviceLimit // ignore: cast_nullable_to_non_nullable
              as int?,
      sell: freezed == sell
          ? _value.sell
          : sell // ignore: cast_nullable_to_non_nullable
              as bool?,
      renew: null == renew
          ? _value.renew
          : renew // ignore: cast_nullable_to_non_nullable
              as bool,
      resetTrafficMethod: freezed == resetTrafficMethod
          ? _value.resetTrafficMethod
          : resetTrafficMethod // ignore: cast_nullable_to_non_nullable
              as int?,
      sort: freezed == sort
          ? _value.sort
          : sort // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlanImpl extends _Plan {
  const _$PlanImpl(
      {required this.id,
      @JsonKey(name: 'group_id') this.groupId = 0,
      @JsonKey(name: 'transfer_enable') required this.transferEnable,
      required this.name,
      final List<String>? tags,
      @JsonKey(name: 'speed_limit') this.speedLimit,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) required this.show,
      this.content,
      @JsonKey(
          name: 'onetime_price', fromJson: _priceFromJson, toJson: _priceToJson)
      this.onetimePrice,
      @JsonKey(
          name: 'month_price', fromJson: _priceFromJson, toJson: _priceToJson)
      this.monthPrice,
      @JsonKey(
          name: 'quarter_price', fromJson: _priceFromJson, toJson: _priceToJson)
      this.quarterPrice,
      @JsonKey(
          name: 'half_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      this.halfYearPrice,
      @JsonKey(
          name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
      this.yearPrice,
      @JsonKey(
          name: 'two_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      this.twoYearPrice,
      @JsonKey(
          name: 'three_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      this.threeYearPrice,
      @JsonKey(
          name: 'reset_price', fromJson: _priceFromJson, toJson: _priceToJson)
      this.resetPrice,
      @JsonKey(name: 'capacity_limit') this.capacityLimit,
      @JsonKey(name: 'device_limit') this.deviceLimit,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt, defaultValue: true)
      this.sell,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt) required this.renew,
      @JsonKey(name: 'reset_traffic_method') this.resetTrafficMethod,
      this.sort,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt})
      : _tags = tags,
        super._();

  factory _$PlanImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanImplFromJson(json);

  @override
  final int id;
  @override
  @JsonKey(name: 'group_id')
  final int groupId;
  @override
  @JsonKey(name: 'transfer_enable')
  final double transferEnable;
  @override
  final String name;
  final List<String>? _tags;
  @override
  List<String>? get tags {
    final value = _tags;
    if (value == null) return null;
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'speed_limit')
  final int? speedLimit;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  final bool show;
  @override
  final String? content;
  @override
  @JsonKey(
      name: 'onetime_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? onetimePrice;
  @override
  @JsonKey(name: 'month_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? monthPrice;
  @override
  @JsonKey(
      name: 'quarter_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? quarterPrice;
  @override
  @JsonKey(
      name: 'half_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? halfYearPrice;
  @override
  @JsonKey(name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? yearPrice;
  @override
  @JsonKey(
      name: 'two_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? twoYearPrice;
  @override
  @JsonKey(
      name: 'three_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? threeYearPrice;
  @override
  @JsonKey(name: 'reset_price', fromJson: _priceFromJson, toJson: _priceToJson)
  final double? resetPrice;
  @override
  @JsonKey(name: 'capacity_limit')
  final dynamic capacityLimit;
  @override
  @JsonKey(name: 'device_limit')
  final int? deviceLimit;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt, defaultValue: true)
  final bool? sell;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  final bool renew;
  @override
  @JsonKey(name: 'reset_traffic_method')
  final int? resetTrafficMethod;
  @override
  final int? sort;
  @override
  @JsonKey(name: 'created_at')
  final int? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final int? updatedAt;

  @override
  String toString() {
    return 'Plan(id: $id, groupId: $groupId, transferEnable: $transferEnable, name: $name, tags: $tags, speedLimit: $speedLimit, show: $show, content: $content, onetimePrice: $onetimePrice, monthPrice: $monthPrice, quarterPrice: $quarterPrice, halfYearPrice: $halfYearPrice, yearPrice: $yearPrice, twoYearPrice: $twoYearPrice, threeYearPrice: $threeYearPrice, resetPrice: $resetPrice, capacityLimit: $capacityLimit, deviceLimit: $deviceLimit, sell: $sell, renew: $renew, resetTrafficMethod: $resetTrafficMethod, sort: $sort, createdAt: $createdAt, updatedAt: $updatedAt)';
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
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.speedLimit, speedLimit) ||
                other.speedLimit == speedLimit) &&
            (identical(other.show, show) || other.show == show) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.onetimePrice, onetimePrice) ||
                other.onetimePrice == onetimePrice) &&
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
            (identical(other.resetPrice, resetPrice) ||
                other.resetPrice == resetPrice) &&
            const DeepCollectionEquality()
                .equals(other.capacityLimit, capacityLimit) &&
            (identical(other.deviceLimit, deviceLimit) ||
                other.deviceLimit == deviceLimit) &&
            (identical(other.sell, sell) || other.sell == sell) &&
            (identical(other.renew, renew) || other.renew == renew) &&
            (identical(other.resetTrafficMethod, resetTrafficMethod) ||
                other.resetTrafficMethod == resetTrafficMethod) &&
            (identical(other.sort, sort) || other.sort == sort) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        groupId,
        transferEnable,
        name,
        const DeepCollectionEquality().hash(_tags),
        speedLimit,
        show,
        content,
        onetimePrice,
        monthPrice,
        quarterPrice,
        halfYearPrice,
        yearPrice,
        twoYearPrice,
        threeYearPrice,
        resetPrice,
        const DeepCollectionEquality().hash(capacityLimit),
        deviceLimit,
        sell,
        renew,
        resetTrafficMethod,
        sort,
        createdAt,
        updatedAt
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
      @JsonKey(name: 'group_id') final int groupId,
      @JsonKey(name: 'transfer_enable') required final double transferEnable,
      required final String name,
      final List<String>? tags,
      @JsonKey(name: 'speed_limit') final int? speedLimit,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
      required final bool show,
      final String? content,
      @JsonKey(
          name: 'onetime_price', fromJson: _priceFromJson, toJson: _priceToJson)
      final double? onetimePrice,
      @JsonKey(
          name: 'month_price', fromJson: _priceFromJson, toJson: _priceToJson)
      final double? monthPrice,
      @JsonKey(
          name: 'quarter_price', fromJson: _priceFromJson, toJson: _priceToJson)
      final double? quarterPrice,
      @JsonKey(
          name: 'half_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      final double? halfYearPrice,
      @JsonKey(
          name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
      final double? yearPrice,
      @JsonKey(
          name: 'two_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      final double? twoYearPrice,
      @JsonKey(
          name: 'three_year_price',
          fromJson: _priceFromJson,
          toJson: _priceToJson)
      final double? threeYearPrice,
      @JsonKey(
          name: 'reset_price', fromJson: _priceFromJson, toJson: _priceToJson)
      final double? resetPrice,
      @JsonKey(name: 'capacity_limit') final dynamic capacityLimit,
      @JsonKey(name: 'device_limit') final int? deviceLimit,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt, defaultValue: true)
      final bool? sell,
      @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
      required final bool renew,
      @JsonKey(name: 'reset_traffic_method') final int? resetTrafficMethod,
      final int? sort,
      @JsonKey(name: 'created_at') final int? createdAt,
      @JsonKey(name: 'updated_at') final int? updatedAt}) = _$PlanImpl;
  const _Plan._() : super._();

  factory _Plan.fromJson(Map<String, dynamic> json) = _$PlanImpl.fromJson;

  @override
  int get id;
  @override
  @JsonKey(name: 'group_id')
  int get groupId;
  @override
  @JsonKey(name: 'transfer_enable')
  double get transferEnable;
  @override
  String get name;
  @override
  List<String>? get tags;
  @override
  @JsonKey(name: 'speed_limit')
  int? get speedLimit;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool get show;
  @override
  String? get content;
  @override
  @JsonKey(
      name: 'onetime_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get onetimePrice;
  @override
  @JsonKey(name: 'month_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get monthPrice;
  @override
  @JsonKey(
      name: 'quarter_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get quarterPrice;
  @override
  @JsonKey(
      name: 'half_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get halfYearPrice;
  @override
  @JsonKey(name: 'year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get yearPrice;
  @override
  @JsonKey(
      name: 'two_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get twoYearPrice;
  @override
  @JsonKey(
      name: 'three_year_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get threeYearPrice;
  @override
  @JsonKey(name: 'reset_price', fromJson: _priceFromJson, toJson: _priceToJson)
  double? get resetPrice;
  @override
  @JsonKey(name: 'capacity_limit')
  dynamic get capacityLimit;
  @override
  @JsonKey(name: 'device_limit')
  int? get deviceLimit;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt, defaultValue: true)
  bool? get sell;
  @override
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  bool get renew;
  @override
  @JsonKey(name: 'reset_traffic_method')
  int? get resetTrafficMethod;
  @override
  int? get sort;
  @override
  @JsonKey(name: 'created_at')
  int? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  int? get updatedAt;

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanImplCopyWith<_$PlanImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlanResponse _$PlanResponseFromJson(Map<String, dynamic> json) {
  return _PlanResponse.fromJson(json);
}

/// @nodoc
mixin _$PlanResponse {
  List<Plan> get data => throw _privateConstructorUsedError;
  int? get total => throw _privateConstructorUsedError;

  /// Serializes this PlanResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlanResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanResponseCopyWith<PlanResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanResponseCopyWith<$Res> {
  factory $PlanResponseCopyWith(
          PlanResponse value, $Res Function(PlanResponse) then) =
      _$PlanResponseCopyWithImpl<$Res, PlanResponse>;
  @useResult
  $Res call({List<Plan> data, int? total});
}

/// @nodoc
class _$PlanResponseCopyWithImpl<$Res, $Val extends PlanResponse>
    implements $PlanResponseCopyWith<$Res> {
  _$PlanResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlanResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? data = null,
    Object? total = freezed,
  }) {
    return _then(_value.copyWith(
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as List<Plan>,
      total: freezed == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlanResponseImplCopyWith<$Res>
    implements $PlanResponseCopyWith<$Res> {
  factory _$$PlanResponseImplCopyWith(
          _$PlanResponseImpl value, $Res Function(_$PlanResponseImpl) then) =
      __$$PlanResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<Plan> data, int? total});
}

/// @nodoc
class __$$PlanResponseImplCopyWithImpl<$Res>
    extends _$PlanResponseCopyWithImpl<$Res, _$PlanResponseImpl>
    implements _$$PlanResponseImplCopyWith<$Res> {
  __$$PlanResponseImplCopyWithImpl(
      _$PlanResponseImpl _value, $Res Function(_$PlanResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlanResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? data = null,
    Object? total = freezed,
  }) {
    return _then(_$PlanResponseImpl(
      data: null == data
          ? _value._data
          : data // ignore: cast_nullable_to_non_nullable
              as List<Plan>,
      total: freezed == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlanResponseImpl extends _PlanResponse {
  const _$PlanResponseImpl({required final List<Plan> data, this.total})
      : _data = data,
        super._();

  factory _$PlanResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanResponseImplFromJson(json);

  final List<Plan> _data;
  @override
  List<Plan> get data {
    if (_data is EqualUnmodifiableListView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_data);
  }

  @override
  final int? total;

  @override
  String toString() {
    return 'PlanResponse(data: $data, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanResponseImpl &&
            const DeepCollectionEquality().equals(other._data, _data) &&
            (identical(other.total, total) || other.total == total));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_data), total);

  /// Create a copy of PlanResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanResponseImplCopyWith<_$PlanResponseImpl> get copyWith =>
      __$$PlanResponseImplCopyWithImpl<_$PlanResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlanResponseImplToJson(
      this,
    );
  }
}

abstract class _PlanResponse extends PlanResponse {
  const factory _PlanResponse(
      {required final List<Plan> data, final int? total}) = _$PlanResponseImpl;
  const _PlanResponse._() : super._();

  factory _PlanResponse.fromJson(Map<String, dynamic> json) =
      _$PlanResponseImpl.fromJson;

  @override
  List<Plan> get data;
  @override
  int? get total;

  /// Create a copy of PlanResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanResponseImplCopyWith<_$PlanResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
