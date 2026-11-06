import '../database/app_database.dart';
import 'enums.dart';

/// Задача вместе с названием проекта и именем исполнителя.
class TaskItem {
  const TaskItem({
    required this.task,
    required this.projectName,
    this.assignee,
  });

  final Task task;
  final String projectName;
  final User? assignee;

  bool get isOverdue =>
      task.status.isOpen &&
      task.deadline != null &&
      task.deadline!.isBefore(DateTime.now());
}

enum TaskSort {
  createdDesc('Сначала новые'),
  createdAsc('Сначала старые'),
  deadlineAsc('Дедлайн: ближайшие'),
  deadlineDesc('Дедлайн: дальние');

  const TaskSort(this.label);
  final String label;
}

/// Параметры поиска, фильтрации и сортировки задач.
class TaskFilter {
  const TaskFilter({
    this.search = '',
    this.status,
    this.priority,
    this.assigneeId,
    this.projectId,
    this.sort = TaskSort.createdDesc,
  });

  final String search;
  final TaskStatus? status;
  final TaskPriority? priority;
  final int? assigneeId;
  final int? projectId;
  final TaskSort sort;

  bool get hasFilters =>
      search.isNotEmpty ||
      status != null ||
      priority != null ||
      assigneeId != null;

  TaskFilter copyWith({
    String? search,
    TaskStatus? Function()? status,
    TaskPriority? Function()? priority,
    int? Function()? assigneeId,
    TaskSort? sort,
  }) => TaskFilter(
    search: search ?? this.search,
    status: status != null ? status() : this.status,
    priority: priority != null ? priority() : this.priority,
    assigneeId: assigneeId != null ? assigneeId() : this.assigneeId,
    projectId: projectId,
    sort: sort ?? this.sort,
  );

  TaskFilter cleared() => TaskFilter(projectId: projectId, sort: sort);
}

/// Данные для создания/редактирования задачи.
class TaskDraft {
  const TaskDraft({
    required this.projectId,
    required this.title,
    this.description = '',
    this.assigneeId,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.todo,
    this.deadline,
  });

  final int? projectId;
  final String title;
  final String description;
  final int? assigneeId;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? deadline;
}

class ProjectItem {
  const ProjectItem({
    required this.project,
    required this.totalTasks,
    required this.doneTasks,
    required this.membersCount,
  });

  final Project project;
  final int totalTasks;
  final int doneTasks;
  final int membersCount;

  double get progress => totalTasks == 0 ? 0 : doneTasks / totalTasks;
}

class MemberItem {
  const MemberItem({required this.user, required this.role});

  final User user;
  final MemberRole role;
}

class CommentItem {
  const CommentItem({required this.comment, required this.author});

  final Comment comment;
  final User author;
}

class HistoryItem {
  const HistoryItem({required this.entry, this.user});

  final TaskHistoryData entry;
  final User? user;
}

class ProjectProgress {
  const ProjectProgress(this.projectId, this.name, this.total, this.done);

  final int projectId;
  final String name;
  final int total;
  final int done;

  double get percent => total == 0 ? 0 : done * 100 / total;
}

class AssigneeCount {
  const AssigneeCount(this.userId, this.name, this.count);

  final int? userId;
  final String name;
  final int count;
}

/// Статистика для Dashboard — все значения считаются SQL-запросами.
class DashboardStats {
  const DashboardStats({
    required this.projects,
    required this.tasks,
    required this.done,
    required this.open,
    required this.overdue,
    required this.byPriority,
    required this.byAssignee,
    required this.projectProgress,
  });

  final int projects;
  final int tasks;
  final int done;
  final int open;
  final int overdue;
  final Map<TaskPriority, int> byPriority;
  final List<AssigneeCount> byAssignee;
  final List<ProjectProgress> projectProgress;
}
