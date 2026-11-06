import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../models/enums.dart';
import '../../models/view_models.dart';
import '../../repositories/project_repository.dart';
import '../../repositories/validators.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      title: 'Проекты',
      actions: actions,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'projects-fab',
        onPressed: () => showProjectForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Проект'),
      ),
      body: StreamBuilder<List<ProjectItem>>(
        stream: context.read<ProjectRepository>().watchProjects(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.folder_open,
              text: 'Создайте первый проект',
              action: FilledButton(
                onPressed: () => showProjectForm(context),
                child: const Text('Новый проект'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => ProjectCard(item: list[i]),
          );
        },
      ),
    );
  }
}

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.item});

  final ProjectItem item;

  @override
  Widget build(BuildContext context) {
    final p = item.project;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(projectId: p.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: Tf.gradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Pill(
                          label: p.status.label,
                          color: Tf.projectStatusColor(p.status),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(item.progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Tf.pink,
                    ),
                  ),
                ],
              ),
              if (p.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  p.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Tf.muted),
                ),
              ],
              const SizedBox(height: 14),
              GradientProgress(value: item.progress),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.task_alt, size: 16, color: Tf.blue),
                  const SizedBox(width: 4),
                  Text(
                    '${item.doneTasks}/${item.totalTasks} задач',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.group_outlined, size: 16, color: Tf.blue),
                  const SizedBox(width: 4),
                  Text(
                    '${item.membersCount}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const Spacer(),
                  if (p.endDate != null) ...[
                    const Icon(Icons.flag_outlined, size: 16, color: Tf.muted),
                    const SizedBox(width: 4),
                    Text(
                      fmtDate(p.endDate),
                      style: const TextStyle(fontSize: 13, color: Tf.muted),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Создание или редактирование проекта.
Future<void> showProjectForm(BuildContext context, {Project? project}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ProjectForm(project: project),
  );
}

class _ProjectForm extends StatefulWidget {
  const _ProjectForm({this.project});

  final Project? project;

  @override
  State<_ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<_ProjectForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.project?.name);
  late final _description = TextEditingController(
    text: widget.project?.description,
  );
  late ProjectStatus _status = widget.project?.status ?? ProjectStatus.active;
  late DateTime? _endDate = widget.project?.endDate;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<ProjectRepository>();
    final nav = Navigator.of(context);
    final p = widget.project;
    final ok = await runGuarded(
      context,
      () => p == null
          ? repo.createProject(
              name: _name.text,
              description: _description.text,
              status: _status,
              endDate: _endDate,
              ownerId: context.read<AppState>().currentUserId,
            )
          : repo.updateProject(
              p.id,
              name: _name.text,
              description: _description.text,
              status: _status,
              endDate: _endDate,
            ),
      success: p == null ? 'Проект создан' : 'Проект сохранён',
    );
    if (ok) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.project == null
                  ? 'Новый проект'
                  : 'Редактирование проекта',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Название'),
              validator: Validators.form(
                (v) => Validators.requireText(v, 'Название', max: 100),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Описание'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<ProjectStatus>(
              segments: [
                for (final s in ProjectStatus.values)
                  ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {_status},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: Tf.blue,
                selectedForegroundColor: Colors.white,
              ),
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined, color: Tf.pink),
              title: const Text('Дата завершения (необязательно)'),
              subtitle: Text(
                _endDate == null ? 'Не задана' : fmtDate(_endDate),
              ),
              trailing: _endDate == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _endDate = null),
                    ),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? now,
                  firstDate: DateTime(now.year - 2),
                  lastDate: DateTime(now.year + 5),
                );
                if (d != null) setState(() => _endDate = d);
              },
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _save, child: const Text('Сохранить')),
          ],
        ),
      ),
    );
  }
}
