//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'repository.g.dart';

/// Repository
///
/// Properties:
/// * [id]
/// * [name]
/// * [fullName]
/// * [private]
/// * [htmlUrl]
/// * [description]
/// * [stargazersCount]
/// * [watchersCount]
/// * [language]
/// * [forksCount]
/// * [openIssuesCount]
@BuiltValue()
abstract class Repository implements Built<Repository, RepositoryBuilder> {
  @BuiltValueField(wireName: r'id')
  int? get id;

  @BuiltValueField(wireName: r'name')
  String? get name;

  @BuiltValueField(wireName: r'full_name')
  String? get fullName;

  @BuiltValueField(wireName: r'private')
  bool? get private;

  @BuiltValueField(wireName: r'html_url')
  String? get htmlUrl;

  @BuiltValueField(wireName: r'description')
  String? get description;

  @BuiltValueField(wireName: r'stargazers_count')
  int? get stargazersCount;

  @BuiltValueField(wireName: r'watchers_count')
  int? get watchersCount;

  @BuiltValueField(wireName: r'language')
  String? get language;

  @BuiltValueField(wireName: r'forks_count')
  int? get forksCount;

  @BuiltValueField(wireName: r'open_issues_count')
  int? get openIssuesCount;

  Repository._();

  factory Repository([void updates(RepositoryBuilder b)]) = _$Repository;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RepositoryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Repository> get serializer => _$RepositorySerializer();
}

class _$RepositorySerializer implements PrimitiveSerializer<Repository> {
  @override
  final Iterable<Type> types = const [Repository, _$Repository];

  @override
  final String wireName = r'Repository';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Repository object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.id != null) {
      yield r'id';
      yield serializers.serialize(
        object.id,
        specifiedType: const FullType(int),
      );
    }
    if (object.name != null) {
      yield r'name';
      yield serializers.serialize(
        object.name,
        specifiedType: const FullType(String),
      );
    }
    if (object.fullName != null) {
      yield r'full_name';
      yield serializers.serialize(
        object.fullName,
        specifiedType: const FullType(String),
      );
    }
    if (object.private != null) {
      yield r'private';
      yield serializers.serialize(
        object.private,
        specifiedType: const FullType(bool),
      );
    }
    if (object.htmlUrl != null) {
      yield r'html_url';
      yield serializers.serialize(
        object.htmlUrl,
        specifiedType: const FullType(String),
      );
    }
    if (object.description != null) {
      yield r'description';
      yield serializers.serialize(
        object.description,
        specifiedType: const FullType(String),
      );
    }
    if (object.stargazersCount != null) {
      yield r'stargazers_count';
      yield serializers.serialize(
        object.stargazersCount,
        specifiedType: const FullType(int),
      );
    }
    if (object.watchersCount != null) {
      yield r'watchers_count';
      yield serializers.serialize(
        object.watchersCount,
        specifiedType: const FullType(int),
      );
    }
    if (object.language != null) {
      yield r'language';
      yield serializers.serialize(
        object.language,
        specifiedType: const FullType(String),
      );
    }
    if (object.forksCount != null) {
      yield r'forks_count';
      yield serializers.serialize(
        object.forksCount,
        specifiedType: const FullType(int),
      );
    }
    if (object.openIssuesCount != null) {
      yield r'open_issues_count';
      yield serializers.serialize(
        object.openIssuesCount,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    Repository object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(
      serializers,
      object,
      specifiedType: specifiedType,
    ).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RepositoryBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.id = valueDes;
          break;
        case r'name':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.name = valueDes;
          break;
        case r'full_name':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.fullName = valueDes;
          break;
        case r'private':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(bool),
                  )
                  as bool;
          result.private = valueDes;
          break;
        case r'html_url':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.htmlUrl = valueDes;
          break;
        case r'description':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.description = valueDes;
          break;
        case r'stargazers_count':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.stargazersCount = valueDes;
          break;
        case r'watchers_count':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.watchersCount = valueDes;
          break;
        case r'language':
          final valueDes =
              serializers.deserialize(
                    value,
                    specifiedType: const FullType(String),
                  )
                  as String;
          result.language = valueDes;
          break;
        case r'forks_count':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.forksCount = valueDes;
          break;
        case r'open_issues_count':
          final valueDes =
              serializers.deserialize(value, specifiedType: const FullType(int))
                  as int;
          result.openIssuesCount = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Repository deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RepositoryBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}
