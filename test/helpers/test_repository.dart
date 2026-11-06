import 'package:lab7/core/network/dio_client.dart';
import 'package:lab7/data/local/post_cache.dart';
import 'package:lab7/data/remote/post_api.dart';
import 'package:lab7/data/repositories/post_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_adapter.dart';

/// Настоящий стек Dio -> Retrofit -> Repository, но с mock-адаптером
/// и in-memory SharedPreferences.
Future<(PostRepository, FakeAdapter, PostCache)> buildRepository(
  FakeHandler handler,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final adapter = FakeAdapter(handler);
  final client = DioClient(adapter: adapter, enableRetry: false);
  final cache = PostCache(prefs);
  return (PostRepository(PostApi(client.dio), cache), adapter, cache);
}
