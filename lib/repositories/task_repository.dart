import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/app_exception.dart';
import '../models/enums.dart';
import '../models/view_models.dart';
import 'validators.dart';

class TaskRepository {
  TaskRepository(this._db);

  final AppDatabase _db;

  /// Максимум незавершённых задач у исполнителя на один дедлайн.
  static const maxTasksPerDeadline = 3;

  static final _openStatuses = [
    TaskStatus.todo.name,
    TaskStatus.inProgress.name,
  ];

  // ---------- чтение ----------

  JoinedSelectStatement<HasResultSet, dynamic> _joined() =>
      _db.select(_db.tasks).join([
        innerJoin(_db.projects, _db.projects.id.equalsExp(_db.tasks.projectId)),
        leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.tasks.assigneeId)),
      ]);

  TaskItem _toItem(TypedResult r) => TaskItem(
    task: r.readTable(_db.tasks),
    projectName: r.readTable(_db.projects).name,
    assignee: r.readTableOrNull(_db.users),
  );

  Expression<bool> _where(TaskFilter f, {bool deleted = false}) {
    final t = _db.tasks;
    Expression<bool> e = deleted
        ? t.deletedAt.isNotNull()
        : t.deletedAt.isNull();
    if (f.projectId != null) e = e & t.projectId.equals(f.projectId!);
    if (f.assigneeId != null) e = e & t.assigneeId.equals(f.assigneeId!);
    if (f.status != null) e = e & t.status.equals(f.status!.name);
    if (f.priority != null) e = e & t.priority.equals(f.priority!.name);
    final s = f.search.trim();
    if (s.isNotEmpty) {
      e =
          e &
          (containsIgnoreCase(t.title, s) |
              containsIgnoreCase(t.description, s));
    }
    return e;
  }

  List<OrderingTerm> _order(TaskSort sort) {
    final t = _db.tasks;
    return switch (sort) {
      TaskSort.createdDesc => [
        OrderingTerm.desc(t.createdAt),
        OrderingTerm.desc(t.id),
      ],
      TaskSort.createdAsc => [
        OrderingTerm.asc(t.createdAt),
        OrderingTerm.asc(t.id),
      ],
      TaskSort.deadlineAsc => [
        OrderingTerm(expression: t.deadline, nulls: NullsOrder.last),
        OrderingTerm.asc(t.id),
      ],
      TaskSort.deadlineDesc => [
        OrderingTerm(
          expression: t.deadline,
          mode: OrderingMode.desc,
          nulls: NullsOrder.last,
        ),
        OrderingTerm.asc(t.id),
      ],
    };
  }

  /// Реактивный список задач с фильтрами и пагинацией (LIMIT/OFFSET).
  Stream<List<TaskItem>> watchTasks(
    TaskFilter filter, {
    int limit = 30,
    int offset = 0,
  }) {
    final q = _joined()
      ..where(_where(filter))
      ..orderBy(_order(filter.sort))
      ..limit(limit, offset: offset);
    return q.watch().map((rows) => rows.map(_toItem).toList());
  }

  Future<List<TaskItem>> getTasks(
    TaskFilter filter, {
    int limit = 30,
    int offset = 0,
  }) {
    final q = _joined()
      ..where(_where(filter))
      ..orderBy(_order(filter.sort))
      ..limit(limit, offset: offset);
    return q.map(_toItem).get();
  }

  Stream<int> watchCount(TaskFilter filter, {bool deleted = false}) {
    final count = _db.tasks.id.count();
    final q = _db.selectOnly(_db.tasks)
      ..addColumns([count])
      ..where(_where(filter, deleted: deleted));
    return q.map((r) => r.read(count) ?? 0).watchSingle();
  }

  Stream<TaskItem?> watchTask(int id) {
    final q = _joined()..where(_db.tasks.id.equals(id));
    return q.watchSingleOrNull().map((r) => r == null ? null : _toItem(r));
  }

  Future<Task?> getTask(int id) =>
      (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Корзина: задачи с заполненным deletedAt.
  Stream<List<TaskItem>> watchTrash() {
    final q = _joined()
      ..where(_db.tasks.deletedAt.isNotNull())
      ..orderBy([OrderingTerm.desc(_db.tasks.deletedAt)]);
    return q.watch().map((rows) => rows.map(_toItem).toList());
  }

  Stream<List<HistoryItem>> watchHistory(int taskId) {
    final q =
        _db.select(_db.taskHistory).join([
            leftOuterJoin(
              _db.users,
              _db.users.id.equalsExp(_db.taskHistory.changedBy),
            ),
          ])
          ..where(_db.taskHistory.taskId.equals(taskId))
          ..orderBy([
            OrderingTerm.desc(_db.taskHistory.changedAt),
            OrderingTerm.desc(_db.taskHistory.id),
          ]);
    return q.watch().map(
      (rows) => rows
          .map(
            (r) => HistoryItem(
              entry: r.readTable(_db.taskHistory),
              user: r.readTableOrNull(_db.users),
            ),
          )
          .toList(),
    );
  }

  Future<List<TaskHistoryData>> getHistory(int taskId) =>
      (_db.select(_db.taskHistory)
            ..where((h) => h.taskId.equals(taskId))
            ..orderBy([(h) => OrderingTerm.asc(h.id)]))
          .get();

  // ---------- создание и изменение ----------

  /// Создание задачи и первой записи истории — в одной транзакции.
  /// Если запись истории не сохранится, задача тоже не сохранится.
  Future<int> createTask(TaskDraft draft, {required int? actorId}) =>
      _db.transaction(() async {
        final title = Validators.requireText(draft.title, 'Название', max: 200);
        final projectId = draft.projectId;
        if (projectId == null)
          throw const ValidationException('Задача должна принадлежать проекту');
        await _ensureProjectExists(projectId);
        if (draft.assigneeId != null) {
          await _ensureMember(projectId, draft.assigneeId!);
          if (draft.status.isOpen)
            await _ensureCapacity(draft.assigneeId!, draft.deadline);
        }

        final now = DateTime.now();
        final id = await _db
            .into(_db.tasks)
            .insert(
              TasksCompanion.insert(
                title: title,
                description: Value(draft.description.trim()),
                projectId: projectId,
                assigneeId: Value(draft.assigneeId),
                priority: Value(draft.priority),
                status: draft.status,
                deadline: Value(draft.deadline),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _addHistory(
          id,
          HistoryEvent.created,
          null,
          draft.status,
          actorId,
        );
        return id;
      });

  /// Редактирование полей задачи (без статуса и исполнителя — для них свои методы).
  Future<void> updateTask(
    int id, {
    required String title,
    required String description,
    required TaskPriority priority,
    DateTime? deadline,
  }) => _db.transaction(() async {
    final task = await _requireTask(id);
    if (task.assigneeId != null &&
        task.status.isOpen &&
        !_sameDay(task.deadline, deadline)) {
      await _ensureCapacity(task.assigneeId!, deadline, excludeTaskId: id);
    }
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        title: Value(Validators.requireText(title, 'Название', max: 200)),
        description: Value(description.trim()),
        priority: Value(priority),
        deadline: Value(deadline),
        updatedAt: Value(DateTime.now()),
      ),
    );
  });

  Future<void> changePriority(int id, TaskPriority priority) async {
    await _requireTask(id);
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        priority: Value(priority),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Смена статуса + автоматическая запись в историю (атомарно).
  Future<void> changeStatus(
    int id,
    TaskStatus status, {
    required int? actorId,
  }) => _db.transaction(() async {
    final task = await _requireTask(id);
    if (task.status == status) return;
    // Возврат в работу снова занимает «слот» исполнителя на дедлайн
    if (!task.status.isOpen && status.isOpen && task.assigneeId != null) {
      await _ensureCapacity(task.assigneeId!, task.deadline, excludeTaskId: id);
    }
    await _setStatus(id, status);
    await _addHistory(
      id,
      HistoryEvent.statusChanged,
      task.status,
      status,
      actorId,
    );
  });

  /// Undo: возвращает статус из последнего неотменённого изменения.
  /// Возвращает false, если отменять нечего.
  Future<bool> undoLastStatusChange(int id, {required int? actorId}) =>
      _db.transaction(() async {
        final task = await _requireTask(id);
        final last =
            await (_db.select(_db.taskHistory)
                  ..where(
                    (h) =>
                        h.taskId.equals(id) &
                        h.event.equals(HistoryEvent.statusChanged.name) &
                        h.reverted.equals(false),
                  )
                  ..orderBy([(h) => OrderingTerm.desc(h.id)])
                  ..limit(1))
                .getSingleOrNull();
        if (last == null || last.oldStatus == null) return false;

        final previous = last.oldStatus!;
        await _setStatus(id, previous);
        await (_db.update(_db.taskHistory)..where((h) => h.id.equals(last.id)))
            .write(const TaskHistoryCompanion(reverted: Value(true)));
        await _addHistory(
          id,
          HistoryEvent.undo,
          task.status,
          previous,
          actorId,
          details:
              'Отменено: ${last.oldStatus!.label} → ${last.newStatus.label}',
        );
        return true;
      });

  Future<bool> canUndo(int id) async {
    final row =
        await (_db.select(_db.taskHistory)
              ..where(
                (h) =>
                    h.taskId.equals(id) &
                    h.event.equals(HistoryEvent.statusChanged.name) &
                    h.reverted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Переназначение: проверка участия в проекте, лимита задач,
  /// изменение исполнителя и запись в историю — атомарно.
  Future<void> reassign(int id, int? newAssigneeId, {required int? actorId}) =>
      _db.transaction(() async {
        final task = await _requireTask(id);
        if (task.assigneeId == newAssigneeId) return;
        if (newAssigneeId != null) {
          await _ensureMember(task.projectId, newAssigneeId);
          if (task.status.isOpen) {
            await _ensureCapacity(
              newAssigneeId,
              task.deadline,
              excludeTaskId: id,
            );
          }
        }
        await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          TasksCompanion(
            assigneeId: Value(newAssigneeId),
            updatedAt: Value(DateTime.now()),
          ),
        );
        final oldName = await _userName(task.assigneeId);
        final newName = await _userName(newAssigneeId);
        await _addHistory(
          id,
          HistoryEvent.assigneeChanged,
          task.status,
          task.status,
          actorId,
          details: '$oldName → $newName',
        );
      });

  // ---------- корзина (soft delete) ----------

  Future<void> softDelete(int id) async {
    await _requireTask(id);
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  Future<void> restore(int id) async {
    final task = await getTask(id);
    if (task == null) throw const NotFoundException('Задача не найдена');
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Полное удаление: комментарии, вложения и история удаляются каскадно.
  Future<void> deleteForever(int id) =>
      (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();

  Future<void> emptyTrash() =>
      (_db.delete(_db.tasks)..where((t) => t.deletedAt.isNotNull())).go();

  // ---------- проверки ----------

  /// Задание 3: не больше 3 незавершённых задач на один дедлайн.
  /// Проверка выполняется SQL-запросом COUNT.
  Future<void> _ensureCapacity(
    int assigneeId,
    DateTime? deadline, {
    int? excludeTaskId,
  }) async {
    if (deadline == null) return;
    final dayStart = DateTime(deadline.year, deadline.month, deadline.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final t = _db.tasks;
    final count = t.id.count();
    var where =
        t.assigneeId.equals(assigneeId) &
        t.deletedAt.isNull() &
        t.status.isIn(_openStatuses) &
        t.deadline.isBiggerOrEqualValue(dayStart) &
        t.deadline.isSmallerThanValue(dayEnd);
    if (excludeTaskId != null) where = where & t.id.equals(excludeTaskId).not();
    final row =
        await (_db.selectOnly(t)
              ..addColumns([count])
              ..where(where))
            .getSingle();
    if ((row.read(count) ?? 0) >= maxTasksPerDeadline) {
      throw const AssigneeOverloadedException();
    }
  }

  Future<void> _ensureMember(int projectId, int userId) async {
    final row =
        await (_db.select(_db.projectMembers)..where(
              (m) => m.projectId.equals(projectId) & m.userId.equals(userId),
            ))
            .getSingleOrNull();
    if (row == null) throw const AssigneeNotMemberException();
  }

  Future<void> _ensureProjectExists(int projectId) async {
    final p = await (_db.select(
      _db.projects,
    )..where((p) => p.id.equals(projectId))).getSingleOrNull();
    if (p == null) throw const NotFoundException('Проект не найден');
  }

  Future<Task> _requireTask(int id) async {
    final task = await getTask(id);
    if (task == null || task.deletedAt != null) {
      throw const NotFoundException('Задача не найдена');
    }
    return task;
  }

  Future<void> _setStatus(int id, TaskStatus status) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(status: Value(status), updatedAt: Value(DateTime.now())),
      );

  Future<void> _addHistory(
    int taskId,
    HistoryEvent event,
    TaskStatus? oldStatus,
    TaskStatus newStatus,
    int? actorId, {
    String? details,
  }) => _db
      .into(_db.taskHistory)
      .insert(
        TaskHistoryCompanion.insert(
          taskId: taskId,
          event: event,
          oldStatus: Value(oldStatus),
          newStatus: newStatus,
          changedBy: Value(actorId),
          changedAt: DateTime.now(),
          details: Value(details),
        ),
      );

  Future<String> _userName(int? id) async {
    if (id == null) return 'не назначен';
    final u = await (_db.select(
      _db.users,
    )..where((u) => u.id.equals(id))).getSingleOrNull();
    return u?.name ?? 'удалён';
  }

  bool _sameDay(DateTime? a, DateTime? b) =>
      a?.year == b?.year && a?.month == b?.month && a?.day == b?.day;
}
