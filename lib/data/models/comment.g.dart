// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Comment _$CommentFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Comment', json, ($checkedConvert) {
      final val = Comment(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        postId: $checkedConvert('postId', (v) => (v as num).toInt()),
        name: $checkedConvert('name', (v) => v as String),
        email: $checkedConvert('email', (v) => v as String?),
        body: $checkedConvert('body', (v) => v as String? ?? ''),
      );
      return val;
    });

Map<String, dynamic> _$CommentToJson(Comment instance) => <String, dynamic>{
  'id': instance.id,
  'postId': instance.postId,
  'name': instance.name,
  'email': instance.email,
  'body': instance.body,
};
