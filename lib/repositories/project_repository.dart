import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/app_exception.dart';
import '../models/enums.dart';
import '../models/view_models.dart';
import 'validators.dart';

class ProjectRepository {
  ProjectRepository(this._db);

  final AppDatabase _db;

  /// Проекты с прогрессом — один SQL-запрос с подзапросами.
  Stream<List<ProjectItem>> watchProjects() {
    return _db
        .customSelect(
          '''
          SELECT p.*,
            (SELECT COUNT(*) FROM tasks t
              WHERE t.project_id = p.id AND t.deleted_at IS NULL) AS total,
            (SELECT COUNT(*) FROM tasks t
              WHERE t.project_id = p.id AND t.deleted_at IS NULL
                AND t.status = 'done') AS done,
            (SELECT COUNT(*) FROM project_members m
              WHERE m.project_id = p.id) AS members
          FROM projects p
          ORDER BY CASE p.status WHEN 'active' THEN 0 WHEN 'completed' THEN 1 ELSE 2 END,
                   p.created_at DESC
          ''',
          readsFrom: {_db.projects, _db.tasks, _db.projectMembers},
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (r) => ProjectItem(
                  project: _db.projects.map(r.data),
                  totalTasks: r.read<int>('total'),
                  doneTasks: r.read<int>('done'),
                  membersCount: r.read<int>('members'),
                ),
              )
              .toList(),
        );
  }

  Stream<Project?> watchProject(int id) => (_db.select(
    _db.projects,
  )..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<List<Project>> getProjects() => (_db.select(
    _db.projects,
  )..orderBy([(p) => OrderingTerm.asc(p.name)])).get();

  /// Создатель проекта автоматически становится Owner.
  Future<int> createProject({
    required String name,
    String description = '',
    ProjectStatus status = ProjectStatus.active,
    DateTime? endDate,
    int? ownerId,
  }) => _db.transaction(() async {
    final now = DateTime.now();
    _validateDates(now, endDate);
    final id = await _db
        .into(_db.projects)
        .insert(
          ProjectsCompanion.insert(
            name: Validators.requireText(name, 'Название', max: 100),
            description: Value(description.trim()),
            createdAt: now,
            endDate: Value(endDate),
            status: status,
          ),
        );
    if (ownerId != null) await addMember(id, ownerId, MemberRole.owner);
    return id;
  });

  Future<void> updateProject(
    int id, {
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? endDate,
  }) async {
    final project = await (_db.select(
      _db.projects,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    if (project == null) throw const NotFoundException('Проект не найден');
    _validateDates(project.createdAt, endDate);
    await (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
      ProjectsCompanion(
        name: Value(Validators.requireText(name, 'Название', max: 100)),
        description: Value(description.trim()),
        status: Value(status),
        endDate: Value(endDate),
      ),
    );
  }

  /// Задачи, участники, комментарии и т.д. удаляются каскадно (ON DELETE CASCADE).
  Future<void> deleteProject(int id) =>
      (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();

  // ---------- участники (Many-to-Many) ----------

  Stream<List<MemberItem>> watchMembers(int projectId) {
    final q =
        _db.select(_db.projectMembers).join([
            innerJoin(
              _db.users,
              _db.users.id.equalsExp(_db.projectMembers.userId),
            ),
          ])
          ..where(_db.projectMembers.projectId.equals(projectId))
          ..orderBy([OrderingTerm.asc(_db.users.name)]);
    return q.watch().map(
      (rows) =>
          rows
              .map(
                (r) => MemberItem(
                  user: r.readTable(_db.users),
                  role: r.readTable(_db.projectMembers).role,
                ),
              )
              .toList()
            // Owner -> Admin -> Member
            ..sort((a, b) => a.role.index.compareTo(b.role.index)),
    );
  }

  Future<List<User>> getMembers(int projectId) {
    final q =
        _db.select(_db.users).join([
            innerJoin(
              _db.projectMembers,
              _db.projectMembers.userId.equalsExp(_db.users.id),
            ),
          ])
          ..where(_db.projectMembers.projectId.equals(projectId))
          ..orderBy([OrderingTerm.asc(_db.users.name)]);
    return q.map((r) => r.readTable(_db.users)).get();
  }

  Stream<List<Project>> watchProjectsOfUser(int userId) {
    final q = _db.select(_db.projects).join([
      innerJoin(
        _db.projectMembers,
        _db.projectMembers.projectId.equalsExp(_db.projects.id),
      ),
    ])..where(_db.projectMembers.userId.equals(userId));
    return q.map((r) => r.readTable(_db.projects)).watch();
  }

  Future<bool> isMember(int projectId, int userId) async {
    final row =
        await (_db.select(_db.projectMembers)..where(
              (m) => m.projectId.equals(projectId) & m.userId.equals(userId),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<void> addMember(int projectId, int userId, MemberRole role) async {
    if (await isMember(projectId, userId))
      throw const DuplicateMemberException();
    await _db
        .into(_db.projectMembers)
        .insert(
          ProjectMembersCompanion.insert(
            projectId: projectId,
            userId: userId,
            role: role,
            joinedAt: DateTime.now(),
          ),
        );
  }

  Future<void> changeRole(int projectId, int userId, MemberRole role) =>
      (_db.update(_db.projectMembers)..where(
            (m) => m.projectId.equals(projectId) & m.userId.equals(userId),
          ))
          .write(ProjectMembersCompanion(role: Value(role)));

  /// Исключённый участник больше не может быть исполнителем —
  /// с его задач в этом проекте снимается назначение (в одной транзакции).
  Future<void> removeMember(int projectId, int userId) =>
      _db.transaction(() async {
        await (_db.update(_db.tasks)..where(
              (t) =>
                  t.projectId.equals(projectId) & t.assigneeId.equals(userId),
            ))
            .write(
              TasksCompanion(
                assigneeId: const Value(null),
                updatedAt: Value(DateTime.now()),
              ),
            );
        await (_db.delete(_db.projectMembers)..where(
              (m) => m.projectId.equals(projectId) & m.userId.equals(userId),
            ))
            .go();
      });

  void _validateDates(DateTime createdAt, DateTime? endDate) {
    if (endDate != null &&
        endDate.isBefore(
          DateTime(createdAt.year, createdAt.month, createdAt.day),
        )) {
      throw const ValidationException('Дата завершения раньше даты создания');
    }
  }
}
