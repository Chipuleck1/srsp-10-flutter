import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../../data/models/post.dart';
import '../../data/models/user.dart';
import '../../data/repositories/post_repository.dart';
import 'post_filters.dart';

/// Состояние основного списка (первичная загрузка).
enum ListStatus { loading, success, cached, error }

/// Состояние подгрузки следующей страницы — отдельно от основного,
/// чтобы не держать один общий флаг isLoading.
enum PageStatus { idle, loading, error, noMore }

class PostListNotifier extends ChangeNotifier {
  PostListNotifier(this._repository);

  final PostRepository _repository;

  // --- список ---
  ListStatus status = ListStatus.loading;
  PageStatus pageStatus = PageStatus.idle;
  String? errorMessage; // ошибка первичной загрузки / обновления
  String? pageErrorMessage; // ошибка подгрузки страницы
  DateTime? cacheSavedAt;
  bool isRefreshing = false;

  List<Post> _serverPosts = [];
  final List<Post> _localPosts = [];
  int _currentPage = 0;
  int? _loadingPage;

  /// Номер «поколения» запросов. При смене фильтра увеличивается,
  /// и ответы на старые запросы игнорируются — результаты не смешиваются.
  int _generation = 0;

  // --- фильтры ---
  String query = '';
  int? authorId;
  bool sortDesc = false;

  // --- авторы ---
  List<User> users = [];
  String? usersError;

  bool get hasActiveFilters => query.isNotEmpty || authorId != null || sortDesc;
  int get loadedCount => _serverPosts.length;

  /// Что видит пользователь: локально созданные + серверные посты
  /// с учётом поиска по заголовку и сортировки.
  List<Post> get visiblePosts => applyPostFilters(
    [..._localPosts, ..._serverPosts],
    query: query,
    userId: authorId,
    sortDesc: sortDesc,
  );

  User? userById(int id) {
    for (final u in users) {
      if (u.id == id) return u;
    }
    return null;
  }

  Future<void> init() async {
    await Future.wait([loadUsers(), loadFirstPage()]);
  }

  Future<void> loadUsers() async {
    try {
      users = await _repository.fetchUsers();
      usersError = null;
    } on AppException catch (e) {
      usersError = e.message;
    }
    notifyListeners();
  }

  /// Первая страница: сначала кэш, затем свежие данные с сервера.
  Future<void> loadFirstPage() async {
    final gen = ++_generation;
    _currentPage = 0;
    _loadingPage = null;
    pageStatus = PageStatus.idle;
    pageErrorMessage = null;
    errorMessage = null;

    final cached = _repository.getCachedPosts(
      userId: authorId,
      sortDesc: sortDesc,
    );
    if (cached != null && cached.posts.isNotEmpty) {
      _serverPosts = cached.posts;
      cacheSavedAt = cached.savedAt;
      status = ListStatus.cached;
      isRefreshing = true;
    } else {
      _serverPosts = [];
      cacheSavedAt = null;
      status = ListStatus.loading;
    }
    notifyListeners();

    await _fetchFirstPage(gen);
  }

  /// Pull-to-refresh: текущие данные остаются на экране, пока идёт запрос.
  Future<void> refresh() async {
    final gen = ++_generation;
    _loadingPage = null;
    isRefreshing = true;
    errorMessage = null;
    notifyListeners();
    await _fetchFirstPage(gen);
  }

  Future<void> _fetchFirstPage(int gen) async {
    try {
      final posts = await _repository.fetchPosts(
        page: 1,
        userId: authorId,
        sortDesc: sortDesc,
      );
      if (gen != _generation) return; // фильтр уже сменился
      _serverPosts = posts;
      _currentPage = 1;
      cacheSavedAt = null;
      status = ListStatus.success;
      pageStatus = posts.length < PostRepository.pageSize
          ? PageStatus.noMore
          : PageStatus.idle;
    } on AppException catch (e) {
      if (gen != _generation) return;
      errorMessage = e.message;
      // Последний успешный результат при ошибке не удаляем
      if (_serverPosts.isNotEmpty) {
        status = ListStatus.cached;
        cacheSavedAt ??= DateTime.now();
      } else {
        status = ListStatus.error;
      }
      // Без свежей первой страницы следующие страницы не грузим
      if (_currentPage == 0) pageStatus = PageStatus.noMore;
    } finally {
      if (gen == _generation) {
        isRefreshing = false;
        notifyListeners();
      }
    }
  }

  /// Подгрузка следующей страницы при прокрутке.
  Future<void> loadNextPage() async {
    if (status != ListStatus.success) return;
    if (pageStatus == PageStatus.loading || pageStatus == PageStatus.noMore) {
      return;
    }
    final nextPage = _currentPage + 1;
    // Защита от повторной загрузки одной и той же страницы
    if (_loadingPage == nextPage) return;

    final gen = _generation;
    _loadingPage = nextPage;
    pageStatus = PageStatus.loading;
    pageErrorMessage = null;
    notifyListeners();

    try {
      final posts = await _repository.fetchPosts(
        page: nextPage,
        userId: authorId,
        sortDesc: sortDesc,
        alreadyLoaded: _serverPosts,
      );
      if (gen != _generation) return;
      final knownIds = _serverPosts.map((p) => p.id).toSet();
      _serverPosts = [
        ..._serverPosts,
        ...posts.where((p) => !knownIds.contains(p.id)),
      ];
      _currentPage = nextPage;
      pageStatus = posts.length < PostRepository.pageSize
          ? PageStatus.noMore
          : PageStatus.idle;
    } on AppException catch (e) {
      if (gen != _generation) return;
      pageStatus = PageStatus.error;
      pageErrorMessage = e.message;
    } finally {
      if (gen == _generation) {
        _loadingPage = null;
        notifyListeners();
      }
    }
  }

  // --- фильтры ---

  void setQuery(String value) {
    query = value;
    notifyListeners(); // поиск локальный, запрос не нужен
  }

  void setAuthor(int? userId) {
    if (authorId == userId) return;
    authorId = userId;
    loadFirstPage(); // сброс страниц
  }

  void toggleSort() {
    sortDesc = !sortDesc;
    loadFirstPage();
  }

  void resetFilters() {
    final needReload = authorId != null || sortDesc;
    query = '';
    authorId = null;
    sortDesc = false;
    if (needReload) {
      loadFirstPage();
    } else {
      notifyListeners();
    }
  }

  /// Пост, созданный через POST, хранится только локально.
  void addLocalPost(Post post) {
    _localPosts.insert(0, post.copyWith(isLocal: true));
    notifyListeners();
  }
}
