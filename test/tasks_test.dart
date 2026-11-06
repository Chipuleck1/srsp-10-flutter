import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lab10/database/app_database.dart';
import 'package:lab10/models/app_exception.dart';
import 'package:lab10/models/enums.dart';
import 'package:lab10/models/view_models.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;
  late int anna;
  late int ivan;
  late int project;

  setUp(() async {
    env = TestEnv();
    anna = await env.user('Анна');
    ivan = await env.user('Иван');
    project = await env.project([anna]); // Иван НЕ участник
  });
  tearDown(() => env.close());

  test('8. создание задачи + первая запись истории', () async {
    final id = await env.task(
      project,
      title: 'Сверстать экран',
      assigneeId: anna,
      actorId: anna,
    );

    final t = await readTask(env, id);
    expect(t.title, 'Сверстать экран');
    expect(t.status, TaskStatus.todo);
    expect(t.priority, TaskPriority.medium);
    final history = await env.tasks.getHistory(id);
    expect(history.single.event, HistoryEvent.created);
    expect(history.single.changedBy, anna);
  });

  test(
    '9. целостность: без проекта, в чужой проект, пустое название',
    () async {
      await expectLater(
        env.tasks.createTask(
          const TaskDraft(projectId: null, title: 'X'),
          actorId: anna,
        ),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(env.task(9999), throwsA(isA<NotFoundException>()));
      await expectLater(
        env.task(project, title: '  '),
        throwsA(isA<ValidationException>()),
      );
      expect(await env.rawCount('tasks'), 0);
    },
  );

  test('10. исполнитель должен быть участником проекта', () async {
    await expectLater(
      env.task(project, assigneeId: ivan),
      throwsA(isA<AssigneeNotMemberException>()),
    );

    final id = await env.task(project, assigneeId: anna);
    await expectLater(
      env.tasks.reassign(id, ivan, actorId: anna),
      throwsA(isA<AssigneeNotMemberException>()),
    );
    expect((await readTask(env, id)).assigneeId, anna); // ничего не изменилось

    await env.projects.addMember(project, ivan, MemberRole.member);
    await env.tasks.reassign(id, ivan, actorId: anna);
    expect((await readTask(env, id)).assigneeId, ivan);
    final last = (await env.tasks.getHistory(id)).last;
    expect(last.event, HistoryEvent.assigneeChanged);
    expect(last.details, 'Анна → Иван');
  });

  test(
    '11. смена статуса сохраняет историю (старый/новый статус, кто, когда)',
    () async {
      final id = await env.task(project, assigneeId: anna, actorId: anna);
      await env.tasks.changeStatus(id, TaskStatus.inProgress, actorId: anna);
      await env.tasks.changeStatus(id, TaskStatus.done, actorId: anna);

      expect((await readTask(env, id)).status, TaskStatus.done);
      final h = await env.tasks.getHistory(id);
      expect(h.map((e) => e.event), [
        HistoryEvent.created,
        HistoryEvent.statusChanged,
        HistoryEvent.statusChanged,
      ]);
      expect(h[1].oldStatus, TaskStatus.todo);
      expect(h[1].newStatus, TaskStatus.inProgress);
      expect(h[2].oldStatus, TaskStatus.inProgress);
      expect(h[2].newStatus, TaskStatus.done);
      expect(h[2].changedBy, anna);
    },
  );

  test('12. транзакция: ошибка записи истории откатывает создание задачи', () async {
    // actorId = 9999 нарушает внешний ключ task_history.changed_by -> users.id,
    // поэтому вставка истории падает, а вместе с ней откатывается и задача.
    await expectLater(
      env.task(project, title: 'Не сохранится', actorId: 9999),
      throwsA(anything),
    );
    expect(await env.rawCount('tasks'), 0);
    expect(await env.rawCount('task_history'), 0);
  });

  test('13. Undo: отмена последнего изменения статуса', () async {
    final id = await env.task(project, actorId: anna);
    expect(
      await env.tasks.undoLastStatusChange(id, actorId: anna),
      isFalse,
    ); // отменять нечего

    await env.tasks.changeStatus(id, TaskStatus.inProgress, actorId: anna);
    await env.tasks.changeStatus(id, TaskStatus.done, actorId: anna);

    expect(await env.tasks.undoLastStatusChange(id, actorId: anna), isTrue);
    expect((await readTask(env, id)).status, TaskStatus.inProgress);
    expect(await env.tasks.undoLastStatusChange(id, actorId: anna), isTrue);
    expect((await readTask(env, id)).status, TaskStatus.todo);
    expect(await env.tasks.canUndo(id), isFalse);
    expect((await env.tasks.getHistory(id)).last.event, HistoryEvent.undo);
  });

  test(
    '14. не более 3 незавершённых задач у исполнителя на один дедлайн',
    () async {
      final day = DateTime(2030, 5, 20, 10);
      for (var i = 0; i < 3; i++) {
        await env.task(
          project,
          assigneeId: anna,
          deadline: day.add(Duration(hours: i)),
        );
      }
      await expectLater(
        env.task(
          project,
          assigneeId: anna,
          deadline: DateTime(2030, 5, 20, 18),
        ),
        throwsA(isA<AssigneeOverloadedException>()),
      );
      // другой день и завершённые задачи не считаются
      await env.task(
        project,
        assigneeId: anna,
        deadline: DateTime(2030, 5, 21),
      );
      await env.task(
        project,
        assigneeId: anna,
        deadline: day,
        status: TaskStatus.done,
      );
      expect(await env.rawCount('tasks'), 5);
    },
  );

  test(
    '15. soft delete: задача уходит в корзину и пропадает из списков',
    () async {
      final id = await env.task(project, title: 'Удаляемая');
      await env.tasks.softDelete(id);

      expect((await readTask(env, id)).deletedAt, isNotNull);
      expect(await env.rawCount('tasks'), 1); // физически осталась
      expect(await env.tasks.getTasks(TaskFilter(projectId: project)), isEmpty);
      expect((await env.tasks.watchTrash().first).single.task.id, id);
      await expectLater(
        env.comments.addComment(id, anna, 'текст'),
        throwsA(isA<NotFoundException>()),
      );
    },
  );

  test('16. восстановление и полное удаление из корзины', () async {
    final a = await env.task(project, title: 'A');
    final b = await env.task(project, title: 'B', actorId: anna);
    await env.comments.addComment(b, anna, 'коммент');
    await env.tasks.softDelete(a);
    await env.tasks.softDelete(b);

    await env.tasks.restore(a);
    expect(
      (await env.tasks.getTasks(TaskFilter(projectId: project))).single.task.id,
      a,
    );

    await env.tasks.deleteForever(b);
    expect(await env.tasks.getTask(b), isNull);
    expect(await env.rawCount('comments'), 0);
    expect(await env.tasks.watchTrash().first, isEmpty);
  });

  test(
    '17. комментарии: только к существующей задаче, удаляет только автор',
    () async {
      await env.projects.addMember(project, ivan, MemberRole.member);
      final id = await env.task(project);
      final c = await env.comments.addComment(id, anna, 'Первый');

      await expectLater(
        env.comments.addComment(9999, anna, 'нет задачи'),
        throwsA(isA<NotFoundException>()),
      );
      await expectLater(
        env.comments.deleteComment(c, actorId: ivan),
        throwsA(isA<ForbiddenException>()),
      );

      final list = await env.comments.watchComments(id).first;
      expect(list.single.comment.body, 'Первый');
      expect(list.single.author.name, 'Анна');

      await env.comments.deleteComment(c, actorId: anna);
      expect(await env.rawCount('comments'), 0);
    },
  );

  test('18. вложения: в базе хранится путь к файлу', () async {
    final id = await env.task(project);
    await env.comments.addAttachment(
      id,
      fileName: 'spec.pdf',
      filePath: '/storage/docs/spec.pdf',
    );
    final a = (await env.comments.watchAttachments(id).first).single;
    expect(a.fileName, 'spec.pdf');
    expect(a.filePath, '/storage/docs/spec.pdf');
  });

  group('19. фильтрация, поиск, сортировка, пагинация', () {
    setUp(() async {
      await env.projects.addMember(project, ivan, MemberRole.member);
      final base = DateTime(2030, 1, 1);
      await env.task(
        project,
        title: 'Дизайн логотипа',
        assigneeId: anna,
        priority: TaskPriority.high,
        deadline: base.add(const Duration(days: 3)),
      );
      await env.task(
        project,
        title: 'API авторизации',
        description: 'Нужен дизайн ответа',
        assigneeId: ivan,
        priority: TaskPriority.low,
        deadline: base.add(const Duration(days: 1)),
      );
      await env.task(
        project,
        title: 'Тесты',
        assigneeId: ivan,
        priority: TaskPriority.high,
        status: TaskStatus.inProgress,
        deadline: base.add(const Duration(days: 2)),
      );
    });

    test('поиск по названию и описанию', () async {
      // «дизайн» есть в названии первой задачи (с заглавной) и в описании второй
      final r = await env.tasks.getTasks(
        TaskFilter(search: 'ДИЗАЙН', projectId: project),
      );
      expect(r.map((t) => t.task.title).toSet(), {
        'Дизайн логотипа',
        'API авторизации',
      });
      final none = await env.tasks.getTasks(
        TaskFilter(search: 'нет такого', projectId: project),
      );
      expect(none, isEmpty);
    });

    test('фильтры по статусу, приоритету, исполнителю', () async {
      final high = await env.tasks.getTasks(
        TaskFilter(priority: TaskPriority.high),
      );
      expect(high.length, 2);
      final ivanHigh = await env.tasks.getTasks(
        TaskFilter(priority: TaskPriority.high, assigneeId: ivan),
      );
      expect(ivanHigh.single.task.title, 'Тесты');
      final inProgress = await env.tasks.getTasks(
        const TaskFilter(status: TaskStatus.inProgress),
      );
      expect(inProgress.single.assignee!.name, 'Иван');
    });

    test('сортировка по дедлайну и пагинация', () async {
      final sorted = await env.tasks.getTasks(
        const TaskFilter(sort: TaskSort.deadlineAsc),
      );
      expect(sorted.map((t) => t.task.title), [
        'API авторизации',
        'Тесты',
        'Дизайн логотипа',
      ]);
      final page2 = await env.tasks.getTasks(
        const TaskFilter(sort: TaskSort.deadlineAsc),
        limit: 2,
        offset: 2,
      );
      expect(page2.single.task.title, 'Дизайн логотипа');
    });
  });

  test(
    '20. реактивность: watch() присылает новые данные после изменения',
    () async {
      final stream = env.tasks.watchTasks(TaskFilter(projectId: project));
      final expectation = expectLater(
        stream.map((l) => l.length),
        emitsInOrder([0, 1]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await env.task(project);
      await expectation;
    },
  );

  test('21. статистика Dashboard считается верно', () async {
    await env.projects.addMember(project, ivan, MemberRole.member);
    final p2 = await env.project([anna], name: 'Второй');
    final past = DateTime.now().subtract(const Duration(days: 2));
    await env.task(
      project,
      assigneeId: anna,
      priority: TaskPriority.critical,
      deadline: past,
    ); // просрочена
    final t2 = await env.task(
      project,
      assigneeId: ivan,
      priority: TaskPriority.high,
    );
    await env.tasks.changeStatus(t2, TaskStatus.done, actorId: ivan);
    await env.task(p2, assigneeId: anna, status: TaskStatus.cancelled);
    final deleted = await env.task(p2);
    await env.tasks.softDelete(deleted); // не учитывается

    final s = await env.stats.loadDashboard();
    expect(s.projects, 2);
    expect(s.tasks, 3);
    expect(s.done, 1);
    expect(s.open, 1);
    expect(s.overdue, 1);
    expect(s.byPriority[TaskPriority.critical], 1);
    expect(s.byPriority[TaskPriority.high], 1);
    expect(s.byPriority[TaskPriority.medium], 1);
    expect(s.byAssignee.firstWhere((a) => a.userId == anna).count, 2);
    final first = s.projectProgress.firstWhere((p) => p.projectId == project);
    expect(first.total, 2);
    expect(first.percent, 50);
  });

  test('проверка через сырой SQL: внешние ключи включены', () async {
    await expectLater(
      env.db
          .into(env.db.tasks)
          .insert(
            TasksCompanion.insert(
              title: 'X',
              projectId: 12345,
              status: TaskStatus.todo,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              assigneeId: const Value(null),
            ),
          ),
      throwsA(anything),
    );
  });
}
