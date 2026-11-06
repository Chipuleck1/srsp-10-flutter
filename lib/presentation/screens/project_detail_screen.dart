import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../models/enums.dart';
import '../../models/view_models.dart';
import '../../repositories/project_repository.dart';
import '../../repositories/task_repository.dart';
import '../../state/task_list_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/task_list_view.dart';
import '../widgets/user_picker.dart';
import 'projects_screen.dart';
import 'task_form_screen.dart';
import 'user_detail_screen.dart';

class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ProjectRepository>();
    return StreamBuilder<Project?>(
      stream: repo.watchProject(projectId),
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) {
          return const GradientScaffold(
            title: 'Проект',
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return DefaultTabController(
          length: 2,
          child: ChangeNotifierProvider(
            create: (ctx) => TaskListController(
              ctx.read<TaskRepository>(),
              projectId: projectId,
            ),
            child: GradientScaffold(
              title: p.name,
              subtitle:
                  '${p.status.label} · с ${fmtDate(p.createdAt)}'
                  '${p.endDate != null ? ' до ${fmtDate(p.endDate)}' : ''}',
              actions: [
                IconButton(
                  tooltip: 'Редактировать',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showProjectForm(context, project: p),
                ),
                IconButton(
                  tooltip: 'Удалить проект',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    if (await confirm(
                      context,
                      'Удалить проект?',
                      'Вместе с проектом будут удалены все его задачи, комментарии и участники.',
                    )) {
                      await repo.deleteProject(p.id);
                      nav.pop();
                    }
                  },
                ),
              ],
              bottom: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: 'Задачи'),
                  Tab(text: 'Участники'),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                heroTag: 'project-fab',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TaskFormScreen(projectId: projectId),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Задача'),
              ),
              body: TabBarView(
                children: [
                  const TaskListView(
                    showProject: false,
                    emptyText: 'В проекте пока нет задач',
                  ),
                  _MembersTab(projectId: projectId),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({required this.projectId});

  final int projectId;

  Future<void> _add(BuildContext context) async {
    final repo = context.read<ProjectRepository>();
    final r = await pickUser(
      context,
      title: 'Добавить участника',
      excludeProjectId: projectId,
    );
    if (r?.user == null || !context.mounted) return;
    final role = await pickOption<MemberRole>(
      context,
      title: 'Роль для ${r!.user!.name}',
      options: MemberRole.values,
      label: (r) => r.label,
      selected: MemberRole.member,
    );
    if (role == null || !context.mounted) return;
    await runGuarded(
      context,
      () => repo.addMember(projectId, r.user!.id, role),
      success: 'Участник добавлен',
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ProjectRepository>();
    return StreamBuilder<List<MemberItem>>(
      stream: repo.watchMembers(projectId),
      builder: (context, snap) {
        final list = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            OutlinedButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Добавить участника'),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(
                  child: Text(
                    'Участников пока нет',
                    style: TextStyle(color: Tf.muted),
                  ),
                ),
              ),
            for (final m in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserDetailScreen(userId: m.user.id),
                      ),
                    ),
                    leading: UserAvatar(
                      name: m.user.name,
                      id: m.user.id,
                      size: 40,
                    ),
                    title: Text(
                      m.user.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(m.user.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Pill(
                          label: m.role.label,
                          color: switch (m.role) {
                            MemberRole.owner => Tf.pink,
                            MemberRole.admin => Tf.blue,
                            MemberRole.member => Tf.muted,
                          },
                          onTap: () async {
                            final role = await pickOption<MemberRole>(
                              context,
                              title: 'Роль',
                              options: MemberRole.values,
                              label: (r) => r.label,
                              selected: m.role,
                            );
                            if (role != null)
                              await repo.changeRole(projectId, m.user.id, role);
                          },
                        ),
                        IconButton(
                          tooltip: 'Исключить',
                          icon: const Icon(
                            Icons.person_remove_outlined,
                            color: Tf.pink,
                          ),
                          onPressed: () async {
                            if (await confirm(
                              context,
                              'Исключить ${m.user.name}?',
                              'С задач этого участника в проекте будет снято назначение.',
                              ok: 'Исключить',
                            )) {
                              await repo.removeMember(projectId, m.user.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
