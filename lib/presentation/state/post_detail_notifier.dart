import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../../data/models/comment.dart';
import '../../data/models/post.dart';
import '../../data/models/user.dart';
import '../../data/repositories/post_repository.dart';
import 'view_state.dart';

/// Пост, автор и комментарии загружаются независимо — у каждого своё состояние.
class PostDetailNotifier extends ChangeNotifier {
  PostDetailNotifier(this._repository, this.initialPost);

  final PostRepository _repository;
  final Post initialPost;

  ViewState<Post> post = const ViewLoading();
  ViewState<User> author = const ViewLoading();
  ViewState<List<Comment>> comments = const ViewLoading();

  void load() {
    if (initialPost.isLocal) {
      // Сервер не хранит созданные посты: GET /posts/101 вернёт 404
      post = ViewSuccess(initialPost);
      comments = const ViewSuccess([]);
    } else {
      _loadPost();
      _loadComments();
    }
    _loadAuthor();
  }

  Future<void> _loadPost() =>
      _run(() => _repository.fetchPost(initialPost.id), (s) => post = s);

  Future<void> _loadComments() => _run(
    () => _repository.fetchComments(initialPost.id),
    (s) => comments = s,
  );

  Future<void> _loadAuthor() =>
      _run(() => _repository.fetchUser(initialPost.userId), (s) => author = s);

  void retryPost() => _loadPost();
  void retryComments() => _loadComments();
  void retryAuthor() => _loadAuthor();

  Future<void> _run<T>(
    Future<T> Function() call,
    void Function(ViewState<T>) set,
  ) async {
    set(ViewLoading<T>());
    notifyListeners();
    try {
      set(ViewSuccess(await call()));
    } on AppException catch (e) {
      set(ViewError<T>(e.message));
    }
    notifyListeners();
  }
}
