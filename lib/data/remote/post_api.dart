import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/comment.dart';
import '../models/post.dart';
import '../models/user.dart';

part 'post_api.g.dart';

/// Описание REST API JSONPlaceholder. Реализацию генерирует retrofit_generator.
@RestApi()
abstract class PostApi {
  factory PostApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) =
      _PostApi;

  /// 1. GET /posts?_page=1&_limit=10 — список постов с пагинацией
  @GET('/posts')
  Future<List<Post>> getPosts(
    @Query('_page') int page,
    @Query('_limit') int limit, {
    @Query('_sort') String? sort,
    @Query('_order') String? order,
  });

  /// 2. GET /posts/{id} — подробная информация о посте
  @GET('/posts/{id}')
  Future<Post> getPost(@Path('id') int id);

  /// 3. GET /posts?userId={id} — посты конкретного пользователя
  @GET('/posts')
  Future<List<Post>> getPostsByUser(
    @Query('userId') int userId,
    @Query('_page') int page,
    @Query('_limit') int limit, {
    @Query('_sort') String? sort,
    @Query('_order') String? order,
  });

  /// 4. GET /posts/{id}/comments — комментарии к посту
  @GET('/posts/{id}/comments')
  Future<List<Comment>> getComments(@Path('id') int postId);

  /// 5. POST /posts — создание поста
  @POST('/posts')
  Future<Post> createPost(@Body() CreatePostRequest request);

  /// Доп.: GET /users — список авторов
  @GET('/users')
  Future<List<User>> getUsers();

  /// Доп.: GET /users/{id} — информация об авторе
  @GET('/users/{id}')
  Future<User> getUser(@Path('id') int id);
}
