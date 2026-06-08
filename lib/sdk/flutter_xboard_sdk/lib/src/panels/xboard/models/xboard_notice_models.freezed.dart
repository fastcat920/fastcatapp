// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'xboard_notice_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Notice _$NoticeFromJson(Map<String, dynamic> json) {
  return _Notice.fromJson(json);
}

/// @nodoc
mixin _$Notice {
  int get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _showFromJson, toJson: _showToJson)
  bool get show => throw _privateConstructorUsedError; // Convert to bool
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

  /// Serializes this Notice to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Notice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NoticeCopyWith<Notice> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NoticeCopyWith<$Res> {
  factory $NoticeCopyWith(Notice value, $Res Function(Notice) then) =
      _$NoticeCopyWithImpl<$Res, Notice>;
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
class _$NoticeCopyWithImpl<$Res, $Val extends Notice>
    implements $NoticeCopyWith<$Res> {
  _$NoticeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Notice
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
abstract class _$$NoticeImplCopyWith<$Res> implements $NoticeCopyWith<$Res> {
  factory _$$NoticeImplCopyWith(
          _$NoticeImpl value, $Res Function(_$NoticeImpl) then) =
      __$$NoticeImplCopyWithImpl<$Res>;
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
class __$$NoticeImplCopyWithImpl<$Res>
    extends _$NoticeCopyWithImpl<$Res, _$NoticeImpl>
    implements _$$NoticeImplCopyWith<$Res> {
  __$$NoticeImplCopyWithImpl(
      _$NoticeImpl _value, $Res Function(_$NoticeImpl) _then)
      : super(_value, _then);

  /// Create a copy of Notice
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
    return _then(_$NoticeImpl(
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
class _$NoticeImpl implements _Notice {
  const _$NoticeImpl(
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

  factory _$NoticeImpl.fromJson(Map<String, dynamic> json) =>
      _$$NoticeImplFromJson(json);

  @override
  final int id;
  @override
  final String title;
  @override
  final String content;
  @override
  @JsonKey(fromJson: _showFromJson, toJson: _showToJson)
  final bool show;
// Convert to bool
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
    return 'Notice(id: $id, title: $title, content: $content, show: $show, imgUrl: $imgUrl, tags: $tags, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NoticeImpl &&
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

  /// Create a copy of Notice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NoticeImplCopyWith<_$NoticeImpl> get copyWith =>
      __$$NoticeImplCopyWithImpl<_$NoticeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NoticeImplToJson(
      this,
    );
  }
}

abstract class _Notice implements Notice {
  const factory _Notice(
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
      required final int updatedAt}) = _$NoticeImpl;

  factory _Notice.fromJson(Map<String, dynamic> json) = _$NoticeImpl.fromJson;

  @override
  int get id;
  @override
  String get title;
  @override
  String get content;
  @override
  @JsonKey(fromJson: _showFromJson, toJson: _showToJson)
  bool get show; // Convert to bool
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

  /// Create a copy of Notice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NoticeImplCopyWith<_$NoticeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$NoticeResponse {
  List<Notice> get data =>
      throw _privateConstructorUsedError; // Renamed from notices to data to match ApiResponse
  int get total => throw _privateConstructorUsedError;

  /// Create a copy of NoticeResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NoticeResponseCopyWith<NoticeResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NoticeResponseCopyWith<$Res> {
  factory $NoticeResponseCopyWith(
          NoticeResponse value, $Res Function(NoticeResponse) then) =
      _$NoticeResponseCopyWithImpl<$Res, NoticeResponse>;
  @useResult
  $Res call({List<Notice> data, int total});
}

/// @nodoc
class _$NoticeResponseCopyWithImpl<$Res, $Val extends NoticeResponse>
    implements $NoticeResponseCopyWith<$Res> {
  _$NoticeResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NoticeResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? data = null,
    Object? total = null,
  }) {
    return _then(_value.copyWith(
      data: null == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as List<Notice>,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NoticeResponseImplCopyWith<$Res>
    implements $NoticeResponseCopyWith<$Res> {
  factory _$$NoticeResponseImplCopyWith(_$NoticeResponseImpl value,
          $Res Function(_$NoticeResponseImpl) then) =
      __$$NoticeResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<Notice> data, int total});
}

/// @nodoc
class __$$NoticeResponseImplCopyWithImpl<$Res>
    extends _$NoticeResponseCopyWithImpl<$Res, _$NoticeResponseImpl>
    implements _$$NoticeResponseImplCopyWith<$Res> {
  __$$NoticeResponseImplCopyWithImpl(
      _$NoticeResponseImpl _value, $Res Function(_$NoticeResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of NoticeResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? data = null,
    Object? total = null,
  }) {
    return _then(_$NoticeResponseImpl(
      data: null == data
          ? _value._data
          : data // ignore: cast_nullable_to_non_nullable
              as List<Notice>,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$NoticeResponseImpl implements _NoticeResponse {
  const _$NoticeResponseImpl(
      {required final List<Notice> data, required this.total})
      : _data = data;

  final List<Notice> _data;
  @override
  List<Notice> get data {
    if (_data is EqualUnmodifiableListView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_data);
  }

// Renamed from notices to data to match ApiResponse
  @override
  final int total;

  @override
  String toString() {
    return 'NoticeResponse(data: $data, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NoticeResponseImpl &&
            const DeepCollectionEquality().equals(other._data, _data) &&
            (identical(other.total, total) || other.total == total));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_data), total);

  /// Create a copy of NoticeResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NoticeResponseImplCopyWith<_$NoticeResponseImpl> get copyWith =>
      __$$NoticeResponseImplCopyWithImpl<_$NoticeResponseImpl>(
          this, _$identity);
}

abstract class _NoticeResponse implements NoticeResponse {
  const factory _NoticeResponse(
      {required final List<Notice> data,
      required final int total}) = _$NoticeResponseImpl;

  @override
  List<Notice> get data; // Renamed from notices to data to match ApiResponse
  @override
  int get total;

  /// Create a copy of NoticeResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NoticeResponseImplCopyWith<_$NoticeResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
