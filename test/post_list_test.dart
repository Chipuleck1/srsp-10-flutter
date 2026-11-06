import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lab7/data/models/post.dart';
import 'package:lab7/presentation/state/post_filters.dart';
import 'package:lab7/presentation/state/post_list_notifier.dart';

import 'helpers/fake_adapter.dart';
import 'helpers/test_repository.dart';

void main() {
  group('5. фильтрация', () {
    const posts = [
      Post(id: 1, userId: 1, title: 'Flutter is great'),
      Post(id: 2, userId: 2, title: 'Dart tips'),
      Post(id: 3, userId: 1, title: 'Dio and Retrofit'),
    ];

    test('по автору', () {
      final r = applyPostFilters(posts, userId: 1);
      expect(r.map((p) => p.id), [1, 3]);
    });

    test('по заголовку без учёта регистра', () {
      final r = applyPostFilters(posts, query: 'DART');
      expect(r.map((p) => p.id), [2]);
    });

    test('сортировка по ID по убыванию', () {
      final r = applyPostFilters(posts, sortDesc: true);
      expect(r.map((p) => p.id), [3, 2, 1]);
    });
  });

  test('6. защита от повторной загрузки одной страницы', () async {
    final page2 = Completer<FakeResponse>();
    final (repo, adapter, _) = await buildRepository((o) async {
      final page = o.queryParameters['_page'];
      if (page == 1) return FakeResponse(fakePosts(1, 10));
      return page2.future;
    });
    final notifier = PostListNotifier(repo);
    await notifier.loadFirstPage();

    // Пользователь быстро скроллит — loadNextPage вызывается несколько раз
    final a = notifier.loadNextPage();
    final b = notifier.loadNextPage();
    final c = notifier.loadNextPage();
    page2.complete(FakeResponse(fakePosts(11, 10)));
    await Future.wait([a, b, c]);

    final page2Requests = adapter.requests.where(
      (r) => r.queryParameters['_page'] == 2,
    );
    expect(page2Requests.length, 1);
    expect(notifier.visiblePosts.length, 20);
    expect(notifier.visiblePosts.map((p) => p.id).toSet().length, 20);
  });

  test(
    'после смены фильтра старые результаты не смешиваются с новыми',
    () async {
      final slowAll = Completer<FakeResponse>();
      final (repo, _, _) = await buildRepository((o) async {
        if (o.queryParameters['userId'] == 2) {
          return FakeResponse(fakePosts(11, 10, userId: 2));
        }
        return slowAll.future;
      });
      final notifier = PostListNotifier(repo);

      final first = notifier
          .loadFirstPage(); // «все посты», ответ задерживается
      notifier.setAuthor(2); // пользователь сразу выбрал автора
      await Future<void>.delayed(Duration.zero);
      slowAll.complete(FakeResponse(fakePosts(1, 10)));
      await first;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.authorId, 2);
      expect(notifier.visiblePosts.every((p) => p.userId == 2), isTrue);
    },
  );

  test('ошибка следующей страницы не удаляет уже загруженные посты', () async {
    final (repo, _, _) = await buildRepository(
      (o) async => o.queryParameters['_page'] == 1
          ? FakeResponse(fakePosts(1, 10))
          : const FakeResponse({}, status: 503),
    );
    final notifier = PostListNotifier(repo);
    await notifier.loadFirstPage();

    await notifier.loadNextPage();

    expect(notifier.pageStatus, PageStatus.error);
    expect(notifier.pageErrorMessage, isNotNull);
    expect(notifier.visiblePosts.length, 10);
  });
}
