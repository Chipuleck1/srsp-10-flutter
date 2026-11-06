import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lab10/database/app_database.dart';
import 'package:lab10/models/enums.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    '22. миграция v1 -> v2: добавляется priority = medium, данные сохраняются',
    () async {
      final dir = await Directory.systemTemp.createTemp('taskflow_migration');
      final file = File('${dir.path}/test.db');

      // 1. Создаём актуальную схему и превращаем её в «версию 1»:
      //    убираем столбец priority, кладём старые данные и ставим user_version = 1.
      final v2 = AppDatabase(NativeDatabase(file, setup: registerSqlFunctions));
      await v2.customSelect('SELECT 1').get(); // создаёт таблицы
      await v2.close();

      final raw = sqlite3.open(file.path);
      raw.execute('DROP INDEX idx_tasks_priority');
      raw.execute('ALTER TABLE tasks DROP COLUMN priority');
      raw.execute(
        "INSERT INTO projects (name, description, created_at, status) VALUES ('Старый', '', 0, 'active')",
      );
      raw.execute(
        "INSERT INTO tasks (title, description, project_id, status, created_at, updated_at) "
        "VALUES ('Задача v1', 'из первой версии', 1, 'todo', 0, 0), "
        "('Вторая v1', '', 1, 'done', 0, 0)",
      );
      raw.execute('PRAGMA user_version = 1');
      final colsBefore = raw
          .select('PRAGMA table_info(tasks)')
          .map((r) => r['name'])
          .toList();
      raw.close();
      expect(colsBefore, isNot(contains('priority')));

      // 2. Открываем базу приложением со schemaVersion = 2 — запускается onUpgrade.
      final migrated = AppDatabase(
        NativeDatabase(file, setup: registerSqlFunctions),
      );
      final tasks = await migrated.select(migrated.tasks).get();
      final version = await migrated
          .customSelect('PRAGMA user_version')
          .getSingle();
      final index = await migrated
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name = 'idx_tasks_priority'",
          )
          .get();
      await migrated.close();
      await dir.delete(recursive: true);

      expect(tasks.length, 2); // данные не потеряны
      expect(tasks.map((t) => t.title), ['Задача v1', 'Вторая v1']);
      expect(tasks.every((t) => t.priority == TaskPriority.medium), isTrue);
      expect(tasks.last.status, TaskStatus.done);
      expect(version.read<int>('user_version'), 2);
      expect(index, hasLength(1));
    },
  );
}
