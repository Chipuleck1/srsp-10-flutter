import 'package:flutter_test/flutter_test.dart';
import 'package:lab7/core/error/app_exception.dart';
import 'package:lab7/data/models/post.dart';
import 'package:lab7/data/models/user.dart';

void main() {
  group('Post JSON', () {
    test('1. JSON -> Post', () {
      final post = Post.fromJson({
        'userId': 1,
        'id': 7,
        'title': 'Hello',
        'body': 'World',
      });

      expect(post.id, 7);
      expect(post.userId, 1);
      expect(post.title, 'Hello');
      expect(post.body, 'World');
      expect(post.isLocal, isFalse);
    });

    test('2. Post -> JSON', () {
      const post = Post(id: 3, userId: 2, title: 'T', body: 'B');

      final json = post.toJson();

      expect(json['id'], 3);
      expect(json['userId'], 2);
      expect(json['title'], 'T');
      expect(json['body'], 'B');
    });

    test('необязательное поле body отсутствует -> пустая строка', () {
      final post = Post.fromJson({'id': 1, 'userId': 1, 'title': 'x'});
      expect(post.body, '');
    });

    test('нет обязательного поля -> ParsingException, а не падение', () {
      Object? caught;
      try {
        Post.fromJson({'userId': 1, 'title': 'no id'});
      } catch (e) {
        caught = e;
      }
      expect(AppException.from(caught!), isA<ParsingException>());
    });
  });

  test('User с вложенными моделями Address/Geo/Company', () {
    final user = User.fromJson({
      'id': 1,
      'name': 'Leanne Graham',
      'address': {
        'city': 'Gwenborough',
        'geo': {'lat': '-37.3159', 'lng': '81.1496'},
      },
      'company': {'name': 'Romaguera-Crona'},
    });

    expect(user.address?.geo?.lat, '-37.3159');
    expect(user.company?.name, 'Romaguera-Crona');
    expect(user.phone, isNull);
    expect(user.toJson()['address']['geo']['lng'], '81.1496');
  });
}
