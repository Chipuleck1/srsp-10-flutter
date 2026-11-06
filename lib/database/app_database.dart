import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:sqlite3/common.dart';

import '../models/enums.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Projects,
    ProjectMembers,
    Tasks,
    Comments,
    Attachments,
    TaskHistory,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'taskflow',
              native: const DriftNativeOptions(setup: registerSqlFunctions),
            ),
      );

  /// v1 — таблица tasks без поля priority.
  /// v2 — добавлено поле priority (по умолчанию medium).
  @override
  int get schemaVersion => 2;

  /// Индексы таблицы tasks — используются в тесте производительности.
  List<Index> get taskIndexes => [
    idxTasksProject,
    idxTasksAssignee,
    idxTasksStatus,
    idxTasksPriority,
    idxTasksDeadline,
    idxTasksCreated,
    idxTasksTitle,
    idxTasksDeleted,
  ];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Новый столбец со значением по умолчанию 'medium':
        // все ранее созданные задачи получают medium, данные не теряются.
        await m.addColumn(tasks, tasks.priority);
        await customStatement(
          'UPDATE tasks SET priority = ? WHERE priority IS NULL',
          [TaskPriority.medium.name],
        );
        await m.createIndex(idxTasksPriority);
      }
    },
    beforeOpen: (details) async {
      // В SQLite внешние ключи по умолчанию выключены
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Встроенный LOWER() в SQLite понимает только латиницу.
/// Регистрируем ulower(), чтобы поиск без учёта регистра работал и для кириллицы.
void registerSqlFunctions(CommonDatabase db) {
  db.createFunction(
    functionName: 'ulower',
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
    function: (args) => (args[0] as String?)?.toLowerCase(),
  );
}

/// ulower(column) LIKE '%query%' — поиск подстроки без учёта регистра.
Expression<bool> containsIgnoreCase(Expression<String> column, String query) =>
    FunctionCallExpression<String>('ulower', [
      column,
    ]).like('%${query.toLowerCase()}%');
