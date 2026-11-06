import '../../data/models/post.dart';

/// Локальная фильтрация и сортировка уже загруженных постов.
/// Чистая функция — легко тестируется.
List<Post> applyPostFilters(
  List<Post> posts, {
  String query = '',
  int? userId,
  bool sortDesc = false,
}) {
  final q = query.trim().toLowerCase();
  final result = posts.where((p) {
    if (userId != null && p.userId != userId) return false;
    if (q.isNotEmpty && !p.title.toLowerCase().contains(q)) return false;
    return true;
  }).toList();

  result.sort((a, b) => sortDesc ? b.id.compareTo(a.id) : a.id.compareTo(b.id));
  return result;
}
