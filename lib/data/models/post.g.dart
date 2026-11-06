// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Post _$PostFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Post', json, ($checkedConvert) {
      final val = Post(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        userId: $checkedConvert('userId', (v) => (v as num).toInt()),
        title: $checkedConvert('title', (v) => v as String),
        body: $checkedConvert('body', (v) => v as String? ?? ''),
        isLocal: $checkedConvert('isLocal', (v) => v as bool? ?? false),
      );
      return val;
    });

Map<String, dynamic> _$PostToJson(Post instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'title': instance.title,
  'body': instance.body,
  'isLocal': instance.isLocal,
};

CreatePostRequest _$CreatePostRequestFromJson(Map<String, dynamic> json) =>
    CreatePostRequest(
      userId: (json['userId'] as num).toInt(),
      title: json['title'] as String,
      body: json['body'] as String,
    );

Map<String, dynamic> _$CreatePostRequestToJson(CreatePostRequest instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'title': instance.title,
      'body': instance.body,
    };
