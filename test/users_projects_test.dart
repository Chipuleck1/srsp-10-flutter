import 'package:flutter_test/flutter_test.dart';
import 'package:lab10/models/app_exception.dart';
import 'package:lab10/models/enums.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  group('Пользователи', () {
    test('1. создание пользователя', () async {
      final id = await env.users.createUser(
        name: ' Анна ',
        email: 'Anna@Mail.KZ',
      );
      final u = (await env.users.getUser(id))!;
      expect(u.name, 'Анна');
      expect(u.email, 'anna@mail.kz'); // нормализуется
      expect(u.registeredAt.difference(DateTime.now()).inMinutes, 0);
    });

    test('2. email уникален', () async {
      await env.users.createUser(name: 'Анна', email: 'a@test.kz');
      await expectLater(
        env.users.createUser(name: 'Другая', email: 'A@test.kz'),
        throwsA(isA<DuplicateEmailException>()),
      );
      // и на уровне БД (UNIQUE) — даже в обход репозитория
      await expectLater(
        env.db.customStatement(
          "INSERT INTO users (name, email, registered_at) VALUES ('X', 'a@test.kz', 0)",
        ),
        throwsA(anything),
      );
    });

    test('3. некорректные данные не сохраняются', () async {
      await expectLater(
        env.users.createUser(name: '', email: 'a@b.kz'),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        env.users.createUser(name: 'A', email: 'not-email'),
        throwsA(isA<ValidationException>()),
      );
      expect(await env.rawCount('users'), 0);
    });

    test(
      '4. удаление пользователя: запрет при незавершённых задачах',
      () async {
        final anna = await env.user('Анна');
        final p = await env.project([anna]);
        final t = await env.task(p, assigneeId: anna);

        await expectLater(
          env.users.deleteUser(anna),
          throwsA(isA<UserHasOpenTasksException>()),
        );

        await env.tasks.changeStatus(t, TaskStatus.done, actorId: anna);
        await env.users.deleteUser(anna);

        expect(await env.users.getUser(anna), isNull);
        expect(await env.rawCount('project_members'), 0); // каскадно
        expect((await readTask(env, t)).assigneeId, isNull); // SET NULL
      },
    );
  });

  group('Проекты и участники', () {
    test('5. создание проекта, создатель становится Owner', () async {
      final anna = await env.user();
      final id = await env.projects.createProject(
        name: 'Сайт',
        description: 'Описание',
        ownerId: anna,
      );

      final items = await env.projects.watchProjects().first;
      expect(items.single.project.id, id);
      expect(items.single.project.status, ProjectStatus.active);
      expect(items.single.membersCount, 1);
      final members = await env.projects.watchMembers(id).first;
      expect(members.single.role, MemberRole.owner);
    });

    test('6. добавление участников, Many-to-Many и запрет дубликата', () async {
      final anna = await env.user('Анна');
      final ivan = await env.user('Иван');
      final p1 = await env.project([anna, ivan], name: 'P1');
      final p2 = await env.project([anna], name: 'P2');

      expect(await env.projects.isMember(p1, ivan), isTrue);
      expect(
        (await env.projects.watchProjectsOfUser(anna).first).map((p) => p.id),
        containsAll([p1, p2]),
      );
      await expectLater(
        env.projects.addMember(p1, anna, MemberRole.admin),
        throwsA(isA<DuplicateMemberException>()),
      );

      await env.projects.changeRole(p1, ivan, MemberRole.admin);
      final members = await env.projects.watchMembers(p1).first;
      expect(
        members.firstWhere((m) => m.user.id == ivan).role,
        MemberRole.admin,
      );
    });

    test('7. удаление проекта каскадно удаляет задачи и комментарии', () async {
      final anna = await env.user();
      final p = await env.project([anna]);
      final t = await env.task(p, assigneeId: anna, actorId: anna);
      await env.comments.addComment(t, anna, 'Привет');

      await env.projects.deleteProject(p);

      expect(await env.rawCount('tasks'), 0);
      expect(await env.rawCount('comments'), 0);
      expect(await env.rawCount('task_history'), 0);
      expect(await env.rawCount('project_members'), 0);
    });
  });
}
