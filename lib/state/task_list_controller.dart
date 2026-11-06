import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/view_models.dart';
import '../repositories/task_repository.dart';

/// Состояние списка задач: фильтры, сортировка, поиск и пагинация.
/// Потоки пересоздаются при смене параметров; данные приходят из Drift watch().
class TaskListController extends ChangeNotifier {
  TaskListController(this._repo, {int? projectId, int? assigneeId})
    : _filter = TaskFilter(projectId: projectId, assigneeId: assigneeId),
      _fixedAssignee = assigneeId != null {
    _rebuild();
  }

  final TaskRepository _repo;
  final bool _fixedAssignee;

  static const pageSize = 30;

  TaskFilter _filter;
  int _limit = pageSize;
  Timer? _debounce;

  late Stream<List<TaskItem>> tasks;
  late Stream<int> total;

  TaskFilter get filter => _filter;
  int get limit => _limit;
  bool get assigneeFixed => _fixedAssignee;

  void _rebuild() {
    tasks = _repo.watchTasks(_filter, limit: _limit);
    total = _repo.watchCount(_filter);
    notifyListeners();
  }

  /// Смена фильтра сбрасывает пагинацию на первую страницу.
  void _apply(TaskFilter f) {
    _filter = f;
    _limit = pageSize;
    _rebuild();
  }

  void setSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _apply(_filter.copyWith(search: value)),
    );
  }

  void setStatus(TaskStatus? s) => _apply(_filter.copyWith(status: () => s));
  void setPriority(TaskPriority? p) =>
      _apply(_filter.copyWith(priority: () => p));
  void setAssignee(int? id) => _apply(_filter.copyWith(assigneeId: () => id));
  void setSort(TaskSort s) => _apply(_filter.copyWith(sort: s));

  void clear() {
    final assignee = _fixedAssignee ? _filter.assigneeId : null;
    _apply(
      TaskFilter(
        projectId: _filter.projectId,
        assigneeId: assignee,
        sort: _filter.sort,
      ),
    );
  }

  bool get hasFilters =>
      _filter.search.isNotEmpty ||
      _filter.status != null ||
      _filter.priority != null ||
      (!_fixedAssignee && _filter.assigneeId != null);

  /// Следующая страница: увеличиваем LIMIT.
  /// [loaded] — сколько строк уже пришло; пока страница грузится, повтор игнорируется.
  void loadMore(int loaded) {
    if (loaded < _limit) return;
    _limit += pageSize;
    _rebuild();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
