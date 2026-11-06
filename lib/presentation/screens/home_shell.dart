import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../repositories/performance_repository.dart';
import '../../repositories/user_repository.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/user_picker.dart';
import 'dashboard_screen.dart';
import 'performance_screen.dart';
import 'projects_screen.dart';
import 'tasks_screen.dart';
import 'trash_screen.dart';
import 'users_screen.dart';

/// Главный экран с нижней навигацией.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<User>>(
      stream: context.read<UserRepository>().watchUsers(limit: 1),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        if (snap.data!.isEmpty) return const WelcomeScreen();

        // Если текущий пользователь не выбран — берём первого
        final app = context.read<AppState>();
        if (app.currentUserId == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => app.setCurrentUser(snap.data!.first.id),
          );
        }

        final actions = [const _CurrentUserButton(), const _MenuButton()];
        final screens = [
          DashboardScreen(actions: actions),
          ProjectsScreen(actions: actions),
          TasksScreen(actions: actions),
          UsersScreen(actions: actions),
        ];
        return Scaffold(
          body: IndexedStack(index: _tab, children: screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: 'Обзор',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: 'Проекты',
              ),
              NavigationDestination(
                icon: Icon(Icons.task_alt_outlined),
                selectedIcon: Icon(Icons.task_alt),
                label: 'Задачи',
              ),
              NavigationDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group),
                label: 'Люди',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Аватар текущего пользователя в шапке — нажатие меняет пользователя.
class _CurrentUserButton extends StatelessWidget {
  const _CurrentUserButton();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final id = app.currentUserId;
    return FutureBuilder<User?>(
      future: id == null
          ? Future.value(null)
          : context.read<UserRepository>().getUser(id),
      builder: (context, snap) {
        final u = snap.data;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              final r = await pickUser(
                context,
                title: 'Кто работает с приложением?',
              );
              if (r?.user != null) await app.setCurrentUser(r!.user!.id);
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: u == null
                  ? const CircleAvatar(
                      radius: 16,
                      child: Icon(Icons.person, size: 18),
                    )
                  : Tooltip(
                      message: 'Вы: ${u.name}',
                      child: UserAvatar(name: u.name, id: u.id, size: 32),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_vert),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (v) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              v == 0 ? const TrashScreen() : const PerformanceScreen(),
        ),
      ),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 0,
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Tf.pink),
            title: Text('Корзина'),
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: ListTile(
            leading: Icon(Icons.speed, color: Tf.blue),
            title: Text('Производительность'),
          ),
        ),
      ],
    );
  }
}

/// Первый запуск: база пустая.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Tf.gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 92,
                    height: 92,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: ShaderMask(
                      shaderCallback: (r) => Tf.gradient.createShader(r),
                      child: const Icon(
                        Icons.task_alt_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'TaskFlow',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Проекты, задачи и команда — всё работает офлайн и хранится в SQLite.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.4,
                  ),
                ),
                const Spacer(flex: 2),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Tf.pink,
                  ),
                  onPressed: _loading
                      ? null
                      : () async {
                          final app = context.read<AppState>();
                          final id = await showUserForm(context);
                          if (id != null) await app.setCurrentUser(id);
                        },
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Создать пользователя'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    minimumSize: const Size(0, 50),
                  ),
                  onPressed: _loading
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          await context
                              .read<PerformanceRepository>()
                              .seedDemo();
                        },
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Заполнить демо-данными'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
