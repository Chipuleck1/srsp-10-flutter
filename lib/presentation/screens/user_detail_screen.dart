import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../repositories/project_repository.dart';
import '../../repositories/task_repository.dart';
import '../../repositories/user_repository.dart';
import '../../state/app_state.dart';
import '../../state/task_list_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/task_list_view.dart';
import 'users_screen.dart';

/// Профиль пользователя и все назначенные ему задачи.
class UserDetailScreen extends StatelessWidget {
  const UserDetailScreen({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<UserRepository>();
    return StreamBuilder<User?>(
      stream: repo.watchUser(userId),
      builder: (context, snap) {
        final u = snap.data;
        if (u == null) {
          return const GradientScaffold(
            title: 'Пользователь',
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return ChangeNotifierProvider(
          create: (ctx) => TaskListController(
            ctx.read<TaskRepository>(),
            assigneeId: userId,
          ),
          child: GradientScaffold(
            title: u.name,
            subtitle: u.email,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Редактировать',
                onPressed: () => showUserForm(context, user: u),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Удалить',
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final app = context.read<AppState>();
                  if (!await confirm(
                    context,
                    'Удалить ${u.name}?',
                    'Пользователь будет исключён из всех проектов.',
                  )) {
                    return;
                  }
                  if (!context.mounted) return;
                  final ok = await runGuarded(
                    context,
                    () => repo.deleteUser(u.id),
                    success: 'Пользователь удалён',
                  );
                  if (ok) {
                    if (app.currentUserId == u.id)
                      await app.setCurrentUser(null);
                    nav.pop();
                  }
                },
              ),
            ],
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          UserAvatar(name: u.name, id: u.id, size: 56),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Зарегистрирован ${fmtDate(u.registeredAt)}',
                                  style: const TextStyle(color: Tf.muted),
                                ),
                                const SizedBox(height: 8),
                                StreamBuilder<List<Project>>(
                                  stream: context
                                      .read<ProjectRepository>()
                                      .watchProjectsOfUser(u.id),
                                  builder: (_, s) {
                                    final projects = s.data ?? [];
                                    if (projects.isEmpty) {
                                      return const Text(
                                        'Не состоит в проектах',
                                        style: TextStyle(fontSize: 13),
                                      );
                                    }
                                    return Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final p in projects.take(6))
                                          Pill(label: p.name, color: Tf.blue),
                                        if (projects.length > 6)
                                          Pill(
                                            label: '+${projects.length - 6}',
                                            color: Tf.pink,
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SectionTitle('Задачи пользователя'),
                ),
                const Expanded(
                  child: TaskListView(emptyText: 'Задачи не назначены'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
