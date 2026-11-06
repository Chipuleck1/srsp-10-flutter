import 'package:drift/native.dart';
import 'package:lab10/database/app_database.dart';
import 'package:lab10/models/enums.dart';
import 'package:lab10/models/view_models.dart';
import 'package:lab10/repositories/comment_repository.dart';
import 'package:lab10/repositories/project_repository.dart';
import 'package:lab10/repositories/stats_repository.dart';
import 'package:lab10/repositories/task_repository.dart';
import 'package:lab10/repositories/user_repository.dart';

/// Настоящая база SQLite в памяти + все репозитории.
class TestEnv {
  TestEnv()
    : db = AppDatabase(NativeDatabase.memory(setup: registerSqlFunctions)) {
    users = UserRepository(db);
    projects = ProjectRepository(db);
    tasks = TaskRepository(db);
    comments = CommentRepository(db);
    stats = StatsRepository(db);
  }

  final AppDatabase db;
  late final UserRepository users;
  late final ProjectRepository projects;
  late final TaskRepository tasks;
  late final CommentRepository comments;
  late final StatsRepository stats;

  int _n = 0;

  Future<int> user([String name = 'Анна']) =>
      users.createUser(name: name, email: 'user${_n++}@test.kz');

  /// Проект с участниками [memberIds].
  Future<int> project(List<int> memberIds, {String name = 'Проект'}) async {
    final id = await projects.createProject(name: name);
    for (final m in memberIds) {
      await projects.addMember(id, m, MemberRole.member);
    }
    return id;
  }

  Future<int> task(
    int projectId, {
    String title = 'Задача',
    String description = '',
    int? assigneeId,
    int? actorId,
    TaskPriority priority = TaskPriority.medium,
    TaskStatus status = TaskStatus.todo,
    DateTime? deadline,
  }) => tasks.createTask(
    TaskDraft(
      projectId: projectId,
      title: title,
      description: description,
      assigneeId: assigneeId,
      priority: priority,
      status: status,
      deadline: deadline,
    ),
    actorId: actorId,
  );

  Future<int> rawCount(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle())
          .read<int>('c');

  Future<void> close() => db.close();
}

/// Для удобства чтения ожиданий.
Future<Task> readTask(TestEnv env, int id) async =>
    (await env.tasks.getTask(id))!;
