import 'package:json_annotation/json_annotation.dart';

part 'post.g.dart';

@JsonSerializable(checked: true)
class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.title,
    this.body = '',
    this.isLocal = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

  final int id;
  final int userId;
  final String title;

  /// Необязательное поле: если сервер не прислал body — пустая строка.
  @JsonKey(defaultValue: '')
  final String body;

  /// Пост создан через POST и хранится только в приложении.
  /// Сервер такого поля не присылает.
  @JsonKey(defaultValue: false)
  final bool isLocal;

  Map<String, dynamic> toJson() => _$PostToJson(this);

  Post copyWith({bool? isLocal}) => Post(
    id: id,
    userId: userId,
    title: title,
    body: body,
    isLocal: isLocal ?? this.isLocal,
  );
}

/// Тело POST /posts.
@JsonSerializable()
class CreatePostRequest {
  const CreatePostRequest({
    required this.userId,
    required this.title,
    required this.body,
  });

  factory CreatePostRequest.fromJson(Map<String, dynamic> json) =>
      _$CreatePostRequestFromJson(json);

  final int userId;
  final String title;
  final String body;

  Map<String, dynamic> toJson() => _$CreatePostRequestToJson(this);
}
