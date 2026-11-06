import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/post.dart';
import '../models/user.dart';

class CachedPosts {
  const CachedPosts(this.posts, this.savedAt);

  final List<Post> posts;
  final DateTime savedAt;
}

/// Простой кэш на SharedPreferences.
/// Для каждого фильтра (все посты / автор, порядок сортировки) свой ключ,
/// чтобы результаты разных фильтров не смешивались.
class PostCache {
  PostCache(this._prefs);

  final SharedPreferences _prefs;

  static const _usersKey = 'cache_users';

  static String postsKey({int? userId, bool sortDesc = false}) =>
      'cache_posts_${userId ?? 'all'}_${sortDesc ? 'desc' : 'asc'}';

  CachedPosts? readPosts({int? userId, bool sortDesc = false}) {
    final raw = _prefs.getString(postsKey(userId: userId, sortDesc: sortDesc));
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final posts = (map['posts'] as List)
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
      return CachedPosts(
        posts,
        DateTime.fromMillisecondsSinceEpoch(map['savedAt'] as int),
      );
    } catch (e) {
      // Повреждённый кэш не должен ронять приложение
      debugPrint('[CACHE] broken posts cache: $e');
      return null;
    }
  }

  Future<void> savePosts(
    List<Post> posts, {
    int? userId,
    bool sortDesc = false,
  }) {
    final data = jsonEncode({
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      'posts': posts.map((p) => p.toJson()).toList(),
    });
    return _prefs.setString(postsKey(userId: userId, sortDesc: sortDesc), data);
  }

  List<User>? readUsers() {
    final raw = _prefs.getString(_usersKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List)
          .map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[CACHE] broken users cache: $e');
      return null;
    }
  }

  Future<void> saveUsers(List<User> users) => _prefs.setString(
    _usersKey,
    jsonEncode(users.map((u) => u.toJson()).toList()),
  );
}
