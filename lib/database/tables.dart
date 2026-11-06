import 'package:drift/drift.dart';

import '../models/enums.dart';

/// users — пользователи. Email уникален.
@TableIndex(name: 'idx_users_name', columns: {#name})
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get email => text().withLength(min: 3, max: 150).unique()();
  DateTimeColumn get registeredAt => dateTime()();
}

/// projects — проекты.
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get status => textEnum<ProjectStatus>()();
}

/// project_members — участники проектов (связь Many-to-Many users <-> projects).
/// Составной первичный ключ запрещает повторно добавить пользователя в проект.
@TableIndex(name: 'idx_members_user', columns: {#userId})
class ProjectMembers extends Table {
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get userId =>
      integer().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => textEnum<MemberRole>()();
  DateTimeColumn get joinedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {projectId, userId};
}

/// tasks — задачи (One-to-Many: проект -> задачи, пользователь -> задачи).
@TableIndex(name: 'idx_tasks_project', columns: {#projectId})
@TableIndex(name: 'idx_tasks_assignee', columns: {#assigneeId})
@TableIndex(name: 'idx_tasks_status', columns: {#status})
@TableIndex(name: 'idx_tasks_priority', columns: {#priority})
@TableIndex(name: 'idx_tasks_deadline', columns: {#deadline})
@TableIndex(name: 'idx_tasks_created', columns: {#createdAt})
@TableIndex(name: 'idx_tasks_title', columns: {#title})
@TableIndex(name: 'idx_tasks_deleted', columns: {#deletedAt})
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get assigneeId => integer().nullable().references(
    Users,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Поле появилось во 2-й версии схемы (см. миграцию в AppDatabase).
  TextColumn get priority => textEnum<TaskPriority>().withDefault(
    Constant(TaskPriority.medium.name),
  )();
  TextColumn get status => textEnum<TaskStatus>()();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete: задача в корзине, если поле заполнено.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// comments — комментарии к задачам.
@TableIndex(name: 'idx_comments_task', columns: {#taskId})
class Comments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get authorId =>
      integer().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get body => text().withLength(min: 1, max: 2000)();
  DateTimeColumn get createdAt => dateTime()();
}

/// attachments — вложения. Хранится путь к файлу, а не содержимое.
@TableIndex(name: 'idx_attachments_task', columns: {#taskId})
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get fileName => text().withLength(min: 1, max: 255)();
  TextColumn get filePath => text()();
  DateTimeColumn get addedAt => dateTime()();
}

/// task_history — история изменений задач.
@TableIndex(name: 'idx_history_task', columns: {#taskId})
class TaskHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get event => textEnum<HistoryEvent>()();
  TextColumn get oldStatus => textEnum<TaskStatus>().nullable()();
  TextColumn get newStatus => textEnum<TaskStatus>()();
  IntColumn get changedBy => integer().nullable().references(
    Users,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get changedAt => dateTime()();

  /// Дополнительные сведения (например, «Анна → Иван» при смене исполнителя).
  TextColumn get details => text().nullable()();

  /// Изменение статуса уже отменено через Undo.
  BoolColumn get reverted => boolean().withDefault(const Constant(false))();
}
