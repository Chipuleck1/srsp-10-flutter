import 'package:json_annotation/json_annotation.dart';

part 'comment.g.dart';

@JsonSerializable(checked: true)
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.name,
    this.email,
    this.body = '',
  });

  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(json);

  final int id;
  final int postId;
  final String name;
  final String? email;

  @JsonKey(defaultValue: '')
  final String body;

  Map<String, dynamic> toJson() => _$CommentToJson(this);
}
