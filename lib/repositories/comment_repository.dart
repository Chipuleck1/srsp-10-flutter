import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/app_exception.dart';
import '../models/view_models.dart';
import 'validators.dart';

/// Комментарии и вложения задачи.
class CommentRepository {
  CommentRepository(this._db);

  final AppDatabase _db;

  Stream<List<CommentItem>> watchComments(int taskId) {
    final q =
        _db.select(_db.comments).join([
            innerJoin(_db.users, _db.users.id.equalsExp(_db.comments.authorId)),
          ])
          ..where(_db.comments.taskId.equals(taskId))
          ..orderBy([OrderingTerm.asc(_db.comments.createdAt)]);
    return q.watch().map(
      (rows) => rows
          .map(
            (r) => CommentItem(
              comment: r.readTable(_db.comments),
              author: r.readTable(_db.users),
            ),
          )
          .toList(),
    );
  }

  /// Комментарий можно добавить только к существующей (не удалённой) задаче.
  Future<int> addComment(int taskId, int authorId, String text) async {
    final body = Validators.requireText(text, 'Комментарий', max: 2000);
    final task = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null || task.deletedAt != null) {
      throw const NotFoundException(
        'Нельзя комментировать несуществующую задачу',
      );
    }
    return _db
        .into(_db.comments)
        .insert(
          CommentsCompanion.insert(
            taskId: taskId,
            authorId: authorId,
            body: body,
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Удалять комментарий может только его автор.
  Future<void> deleteComment(int commentId, {required int actorId}) async {
    final c = await (_db.select(
      _db.comments,
    )..where((c) => c.id.equals(commentId))).getSingleOrNull();
    if (c == null) throw const NotFoundException('Комментарий не найден');
    if (c.authorId != actorId) {
      throw const ForbiddenException(
        'Удалить комментарий может только его автор',
      );
    }
    await (_db.delete(_db.comments)..where((c) => c.id.equals(commentId))).go();
  }

  // ---------- вложения: в базе хранится путь к файлу ----------

  Stream<List<Attachment>> watchAttachments(int taskId) =>
      (_db.select(_db.attachments)
            ..where((a) => a.taskId.equals(taskId))
            ..orderBy([(a) => OrderingTerm.desc(a.addedAt)]))
          .watch();

  Future<int> addAttachment(
    int taskId, {
    required String fileName,
    required String filePath,
  }) async {
    final task = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) throw const NotFoundException('Задача не найдена');
    return _db
        .into(_db.attachments)
        .insert(
          AttachmentsCompanion.insert(
            taskId: taskId,
            fileName: Validators.requireText(fileName, 'Имя файла', max: 255),
            filePath: Validators.requireText(filePath, 'Путь', max: 4096),
            addedAt: DateTime.now(),
          ),
        );
  }

  Future<void> deleteAttachment(int id) =>
      (_db.delete(_db.attachments)..where((a) => a.id.equals(id))).go();
}
