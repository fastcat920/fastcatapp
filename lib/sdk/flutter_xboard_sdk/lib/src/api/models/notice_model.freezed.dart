// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notice_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

NoticeModel _$NoticeModelFromJson(Map<String, dynamic> json) {
  return _NoticeModel.fromJson(json);
}

/// @nodoc
mixin _$NoticeModel {
  int get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _showFromJson, toJson: _showToJson)
  bool get show => throw _privateConstructorUsedError;
  @JsonKey(name: 'img_url')
  String? get imgUrl => throw _privateConstructorUsedError;
  List<String>? get tags => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  int get createdAt => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  int get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this NoticeModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NoticeModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NoticeModelCopyWith<NoticeModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NoticeModelCopyWith<$Res> {
  factory $NoticeModelCopyWith(
          NoticeModel value, $Res Function(NoticeModel) then) =
      _$NoticeModelCopyWithImpl<$Res, NoticeModel>;
  @useResult
  $Res call(
      {int id,
      String title,
      String content,
      @JsonKey(fromJson: _showFromJson, toJson: _showToJson) bool show,
      @JsonKey(name: 'img_url') String? imgUrl,
      List<String>? tags,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      int createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      int updatedAt});
}

/// @nodoc
class _$NoticeModelCopyWithImpl<$Res, $Val extends NoticeModel>
    implements $NoticeModelCopyWith<$Res> {
  _$NoticeModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NoticeModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? content = null,
    Object? show = null,
    Object? imgUrl = freezed,
    Object? tags = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      show: null == show
          ? _value.show
          : show // ignore: cast_nullable_to_non_nullable
              as bool,
      imgUrl: freezed == imgUrl
          ? _value.imgUrl
          : imgUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: freezed == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NoticeModelImplCopyWith<$Res>
    implements $NoticeModelCopyWith<$Res> {
  factory _$$NoticeModelImplCopyWith(
          _$NoticeModelImpl value, $Res Function(_$NoticeModelImpl) then) =
      __$$NoticeModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      String title,
      String content,
      @JsonKey(fromJson: _showFromJson, toJson: _showToJson) bool show,
      @JsonKey(name: 'img_url') String? imgUrl,
      List<String>? tags,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      int createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      int updatedAt});
}

/// @nodoc
class __$$NoticeModelImplCopyWithImpl<$Res>
    extends _$NoticeModelCopyWithImpl<$Res, _$NoticeModelImpl>
    implements _$$NoticeModelImplCopyWith<$Res> {
  __$$NoticeModelImplCopyWithImpl(
      _$NoticeModelImpl _value, $Res Function(_$NoticeModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of NoticeModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? content = null,
    Object? show = null,
    Object? imgUrl = freezed,
    Object? tags = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$NoticeModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      show: null == show
          ? _value.show
          : show // ignore: cast_nullable_to_non_nullable
              as bool,
      imgUrl: freezed == imgUrl
          ? _value.imgUrl
          : imgUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: freezed == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as int,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NoticeModelImpl implements _NoticeModel {
  const _$NoticeModelImpl(
      {required this.id,
      required this.title,
      required this.content,
      @JsonKey(fromJson: _showFromJson, toJson: _showToJson) required this.show,
      @JsonKey(name: 'img_url') this.imgUrl,
      final List<String>? tags,
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
      : _tags = tags;

  factory _$NoticeModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$NoticeModelImplFromJson(json);

  @override
  final int id;
  @override
  final String title;
  @override
  final String content;
  @override
  @JsonKey(fromJson: _showFromJson, toJson: _showToJson)
  final bool show;
  @override
  @JsonKey(name: 'img_url')
  final String? imgUrl;
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
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final int createdAt;
  @override
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  final int updatedAt;

  @override
  String toString() {
    return 'NoticeModel(id: $id, title: $title, content: $content, show: $show, imgUrl: $imgUrl, tags: $tags, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NoticeModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.show, show) || other.show == show) &&
            (identical(other.imgUrl, imgUrl) || other.imgUrl == imgUrl) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, content, show, imgUrl,
      const DeepCollectionEquality().hash(_tags), createdAt, updatedAt);

  /// Create a copy of NoticeModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NoticeModelImplCopyWith<_$NoticeModelImpl> get copyWith =>
      __$$NoticeModelImplCopyWithImpl<_$NoticeModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NoticeModelImplToJson(
      this,
    );
  }
}

abstract class _NoticeModel implements NoticeModel {
  const factory _NoticeModel(
      {required final int id,
      required final String title,
      required final String content,
      @JsonKey(fromJson: _showFromJson, toJson: _showToJson)
      required final bool show,
      @JsonKey(name: 'img_url') final String? imgUrl,
      final List<String>? tags,
      @JsonKey(
          name: 'created_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required final int createdAt,
      @JsonKey(
          name: 'updated_at',
          fromJson: _fromUnixTimestamp,
          toJson: _toUnixTimestamp)
      required final int updatedAt}) = _$NoticeModelImpl;

  factory _NoticeModel.fromJson(Map<String, dynamic> json) =
      _$NoticeModelImpl.fromJson;

  @override
  int get id;
  @override
  String get title;
  @override
  String get content;
  @override
  @JsonKey(fromJson: _showFromJson, toJson: _showToJson)
  bool get show;
  @override
  @JsonKey(name: 'img_url')
  String? get imgUrl;
  @override
  List<String>? get tags;
  @override
  @JsonKey(
      name: 'created_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  int get createdAt;
  @override
  @JsonKey(
      name: 'updated_at',
      fromJson: _fromUnixTimestamp,
      toJson: _toUnixTimestamp)
  int get updatedAt;

  /// Create a copy of NoticeModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NoticeModelImplCopyWith<_$NoticeModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
