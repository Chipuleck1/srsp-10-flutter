import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/app_exception.dart';
import '../models/enums.dart';
import 'validators.dart';

class UserRepository {
  UserRepository(this._db);

  final AppDatabase _db;

  Stream<List<User>> watchUsers({String search = '', int? limit}) {
    final q = _db.select(_db.users);
    if (search.trim().isNotEmpty) {
      final s = search.trim();
      q.where(
        (u) => containsIgnoreCase(u.name, s) | containsIgnoreCase(u.email, s),
      );
    }
    q.orderBy([(u) => OrderingTerm.asc(u.name)]);
    if (limit != null) q.limit(limit);
    return q.watch();
  }

  Stream<User?> watchUser(int id) => (_db.select(
    _db.users,
  )..where((u) => u.id.equals(id))).watchSingleOrNull();

  Future<User?> getUser(int id) =>
      (_db.select(_db.users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<int> createUser({
    required String name,
    required String email,
    DateTime? registeredAt,
  }) async {
    final cleanName = Validators.requireText(name, 'Имя', max: 100);
    final cleanEmail = Validators.email(email);
    await _ensureEmailFree(cleanEmail);
    return _db
        .into(_db.users)
        .insert(
          UsersCompanion.insert(
            name: cleanName,
            email: cleanEmail,
            registeredAt: registeredAt ?? DateTime.now(),
          ),
        );
  }

  Future<void> updateUser(
    int id, {
    required String name,
    required String email,
  }) async {
    final cleanName = Validators.requireText(name, 'Имя', max: 100);
    final cleanEmail = Validators.email(email);
    await _ensureEmailFree(cleanEmail, exceptId: id);
    final updated = await (_db.update(_db.users)..where((u) => u.id.equals(id)))
        .write(
          UsersCompanion(name: Value(cleanName), email: Value(cleanEmail)),
        );
    if (updated == 0) throw const NotFoundException('Пользователь не найден');
  }

  /// Количество незавершённых задач пользователя (без корзины).
  Future<int> countOpenTasks(int userId) async {
    final count = _db.tasks.id.count();
    final row =
        await (_db.selectOnly(_db.tasks)
              ..addColumns([count])
              ..where(
                _db.tasks.assigneeId.equals(userId) &
                    _db.tasks.deletedAt.isNull() &
                    _db.tasks.status.isIn([
                      TaskStatus.todo.name,
                      TaskStatus.inProgress.name,
                    ]),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Удалять пользователя с незавершёнными задачами запрещено.
  /// Остальные связи: членство и комментарии удаляются каскадно,
  /// у завершённых задач исполнитель становится пустым (SET NULL).
  Future<void> deleteUser(int id) => _db.transaction(() async {
    final open = await countOpenTasks(id);
    if (open > 0) throw UserHasOpenTasksException(open);
    final deleted = await (_db.delete(
      _db.users,
    )..where((u) => u.id.equals(id))).go();
    if (deleted == 0) throw const NotFoundException('Пользователь не найден');
  });

  Future<void> _ensureEmailFree(String email, {int? exceptId}) async {
    final q = _db.select(_db.users)..where((u) => u.email.equals(email));
    if (exceptId != null) q.where((u) => u.id.equals(exceptId).not());
    if (await q.getSingleOrNull() != null)
      throw const DuplicateEmailException();
  }
}
