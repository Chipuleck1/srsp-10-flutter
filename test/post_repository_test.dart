import 'package:flutter_test/flutter_test.dart';
import 'package:lab7/core/error/app_exception.dart';
import 'package:lab7/data/models/post.dart';

import 'helpers/fake_adapter.dart';
import 'helpers/test_repository.dart';

void main() {
  test(
    '3. успешная загрузка постов через репозиторий + сохранение в кэш',
    () async {
      final (repo, adapter, cache) = await buildRepository(
        (_) async => FakeResponse(fakePosts(1, 10)),
      );

      final posts = await repo.fetchPosts(page: 1);

      expect(posts.length, 10);
      expect(posts.first.title, 'Post 1');
      // Параметры пагинации ушли в запрос
      final query = adapter.requests.single.queryParameters;
      expect(query['_page'], 1);
      expect(query['_limit'], 10);
      // Технические заголовки добавлены интерцептором
      expect(adapter.requests.single.headers['X-Client-Name'], 'PostExplorer');
      // Кэш обновлён
      expect(cache.readPosts()!.posts.length, 10);
    },
  );

  test('4. ошибка сервера 500 -> ServerException, кэш не стирается', () async {
    var fail = false;
    final (repo, _, cache) = await buildRepository(
      (_) async => fail
          ? const FakeResponse({'error': 'boom'}, status: 500)
          : FakeResponse(fakePosts(1, 10)),
    );

    await repo.fetchPosts(page: 1);
    fail = true;

    await expectLater(
      repo.fetchPosts(page: 1),
      throwsA(
        isA<ServerException>().having((e) => e.statusCode, 'statusCode', 500),
      ),
    );
    expect(cache.readPosts()!.posts.length, 10);
  });

  test('ошибка 404 -> ClientException', () async {
    final (repo, _, _) = await buildRepository(
      (_) async => const FakeResponse({}, status: 404),
    );

    await expectLater(repo.fetchPost(999), throwsA(isA<ClientException>()));
  });

  test('некорректный JSON -> ParsingException', () async {
    final (repo, _, _) = await buildRepository(
      (_) async => const FakeResponse([
        {'title': 'нет id и userId'},
      ]),
    );

    await expectLater(
      repo.fetchPosts(page: 1),
      throwsA(isA<ParsingException>()),
    );
  });

  test(
    'POST через mock-адаптер: пост создан и помечен как локальный',
    () async {
      final (repo, adapter, _) = await buildRepository(
        (o) async => FakeResponse({
          ...(o.data as Map<String, dynamic>),
          'id': 101,
        }, status: 201),
      );

      final post = await repo.createPost(
        const CreatePostRequest(
          userId: 1,
          title: 'Новый пост',
          body: 'Текст нового поста',
        ),
      );

      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/posts');
      expect(post.id, 101);
      expect(post.title, 'Новый пост');
      expect(post.isLocal, isTrue);
    },
  );
}
