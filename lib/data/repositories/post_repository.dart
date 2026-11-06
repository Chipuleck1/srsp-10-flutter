import '../../core/error/app_exception.dart';
import '../local/post_cache.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../remote/post_api.dart';

/// Единственная точка доступа к данным для UI.
/// Скрывает Retrofit/Dio, работает с кэшем и превращает ошибки в [AppException].
class PostRepository {
  PostRepository(this._api, this._cache);

  final PostApi _api;
  final PostCache _cache;

  static const pageSize = 10;

  CachedPosts? getCachedPosts({int? userId, bool sortDesc = false}) =>
      _cache.readPosts(userId: userId, sortDesc: sortDesc);

  /// Загружает страницу с сервера и обновляет кэш.
  /// [alreadyLoaded] — посты предыдущих страниц, чтобы кэш хранил весь список.
  Future<List<Post>> fetchPosts({
    required int page,
    int? userId,
    bool sortDesc = false,
    List<Post> alreadyLoaded = const [],
  }) async {
    final order = sortDesc ? 'desc' : 'asc';
    final posts = await _guard(
      () => userId == null
          ? _api.getPosts(page, pageSize, sort: 'id', order: order)
          : _api.getPostsByUser(
              userId,
              page,
              pageSize,
              sort: 'id',
              order: order,
            ),
    );

    final toCache = page == 1 ? posts : [...alreadyLoaded, ...posts];
    await _cache.savePosts(toCache, userId: userId, sortDesc: sortDesc);
    return posts;
  }

  Future<Post> fetchPost(int id) => _guard(() => _api.getPost(id));

  Future<List<Comment>> fetchComments(int postId) =>
      _guard(() => _api.getComments(postId));

  Future<User> fetchUser(int id) => _guard(() => _api.getUser(id));

  /// Авторы: при ошибке сети возвращаем кэш, если он есть.
  Future<List<User>> fetchUsers() async {
    try {
      final users = await _guard(_api.getUsers);
      await _cache.saveUsers(users);
      return users;
    } on AppException {
      final cached = _cache.readUsers();
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// JSONPlaceholder только имитирует создание: сервер вернёт объект с id=101,
  /// но не сохранит его. Поэтому помечаем пост как локальный.
  Future<Post> createPost(CreatePostRequest request) async {
    final post = await _guard(() => _api.createPost(request));
    return post.copyWith(isLocal: true);
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
