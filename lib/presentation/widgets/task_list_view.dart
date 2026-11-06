import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/view_models.dart';
import '../../repositories/user_repository.dart';
import '../../state/task_list_controller.dart';
import '../screens/task_detail_screen.dart';
import '../theme.dart';
import 'common.dart';
import 'task_card.dart';
import 'user_picker.dart';

class _Choice<T> {
  const _Choice(this.value);
  final T? value;
}

/// Список задач с поиском, фильтрами, сортировкой и бесконечной прокруткой.
/// Ожидает [TaskListController] выше по дереву.
class TaskListView extends StatefulWidget {
  const TaskListView({
    super.key,
    this.showProject = true,
    this.emptyText = 'Задач пока нет',
  });

  final bool showProject;
  final String emptyText;

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaskListController>();
    return Column(
      children: [
        _FilterBar(controller: c, searchController: _search),
        Expanded(
          child: StreamBuilder<List<TaskItem>>(
            stream: c.tasks,
            builder: (context, snap) {
              if (snap.hasError) {
                return EmptyState(
                  icon: Icons.error_outline,
                  text: 'Ошибка: ${snap.error}',
                );
              }
              if (!snap.hasData)
                return const Center(child: CircularProgressIndicator());
              final items = snap.data!;
              if (items.isEmpty) {
                return EmptyState(
                  icon: c.hasFilters ? Icons.search_off : Icons.task_alt,
                  text: c.hasFilters ? 'Ничего не найдено' : widget.emptyText,
                  action: c.hasFilters
                      ? OutlinedButton(
                          onPressed: () {
                            _search.clear();
                            c.clear();
                          },
                          child: const Text('Сбросить фильтры'),
                        )
                      : null,
                );
              }
              final hasMore = items.length >= c.limit;
              return NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (hasMore && n.metrics.extentAfter < 300)
                    c.loadMore(items.length);
                  return false;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == items.length) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: hasMore
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Это все задачи',
                                  style: TextStyle(color: Tf.muted),
                                ),
                        ),
                      );
                    }
                    final item = items[i];
                    return TaskCard(
                      item: item,
                      showProject: widget.showProject,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TaskDetailScreen(taskId: item.task.id),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller, required this.searchController});

  final TaskListController controller;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final f = controller.filter;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            onChanged: controller.setSearch,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Tf.blue),
              hintText: 'Поиск по названию и описанию',
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        searchController.clear();
                        controller.setSearch('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  icon: Icons.flag_outlined,
                  label: f.status?.label ?? 'Статус',
                  active: f.status != null,
                  onTap: () async {
                    final r = await pickOption<_Choice<TaskStatus>>(
                      context,
                      title: 'Статус',
                      options: [
                        const _Choice(null),
                        ...TaskStatus.values.map(_Choice.new),
                      ],
                      label: (c) => c.value?.label ?? 'Все статусы',
                      leading: (c) => Icon(
                        c.value == null
                            ? Icons.all_inclusive
                            : Tf.statusIcon(c.value!),
                        color: c.value == null
                            ? Tf.muted
                            : Tf.statusColor(c.value!),
                      ),
                    );
                    if (r != null) controller.setStatus(r.value);
                  },
                ),
                _FilterChip(
                  icon: Icons.local_fire_department_outlined,
                  label: f.priority?.label ?? 'Приоритет',
                  active: f.priority != null,
                  onTap: () async {
                    final r = await pickOption<_Choice<TaskPriority>>(
                      context,
                      title: 'Приоритет',
                      options: [
                        const _Choice(null),
                        ...TaskPriority.values.map(_Choice.new),
                      ],
                      label: (c) => c.value?.label ?? 'Любой приоритет',
                      leading: (c) => Icon(
                        Icons.circle,
                        size: 14,
                        color: c.value == null
                            ? Tf.border
                            : Tf.priorityColor(c.value!),
                      ),
                    );
                    if (r != null) controller.setPriority(r.value);
                  },
                ),
                if (!controller.assigneeFixed)
                  FutureBuilder(
                    future: f.assigneeId == null
                        ? Future.value(null)
                        : context.read<UserRepository>().getUser(f.assigneeId!),
                    builder: (context, snap) => _FilterChip(
                      icon: Icons.person_outline,
                      label: snap.data?.name ?? 'Исполнитель',
                      active: f.assigneeId != null,
                      onTap: () async {
                        final r = await pickUser(
                          context,
                          title: 'Исполнитель',
                          projectId: f.projectId,
                          noneLabel: 'Все исполнители',
                        );
                        if (r != null) controller.setAssignee(r.user?.id);
                      },
                    ),
                  ),
                _FilterChip(
                  icon: Icons.swap_vert,
                  label: f.sort.label,
                  active: false,
                  onTap: () async {
                    final r = await pickOption<TaskSort>(
                      context,
                      title: 'Сортировка',
                      options: TaskSort.values,
                      label: (s) => s.label,
                      selected: f.sort,
                    );
                    if (r != null) controller.setSort(r);
                  },
                ),
                if (controller.hasFilters)
                  IconButton(
                    tooltip: 'Сбросить фильтры',
                    onPressed: () {
                      searchController.clear();
                      controller.clear();
                    },
                    icon: const Icon(
                      Icons.filter_alt_off_outlined,
                      color: Tf.pink,
                    ),
                  ),
              ],
            ),
          ),
          StreamBuilder<int>(
            stream: controller.total,
            builder: (_, snap) => Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                snap.hasData ? 'Найдено задач: ${snap.data}' : ' ',
                style: const TextStyle(color: Tf.muted, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : Tf.ink;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        shape: StadiumBorder(
          side: BorderSide(color: active ? Colors.transparent : Tf.border),
        ),
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(gradient: active ? Tf.gradient : null),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  Icon(icon, size: 17, color: active ? Colors.white : Tf.blue),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Icon(Icons.expand_more, size: 17, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
