import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../models/enums.dart';
import '../../models/view_models.dart';
import '../../repositories/project_repository.dart';
import '../../repositories/task_repository.dart';
import '../../repositories/validators.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Создание новой задачи ([task] == null) или редактирование существующей.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.task, this.projectId});

  final Task? task;
  final int? projectId;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _description = TextEditingController(
    text: widget.task?.description,
  );
  late int? _projectId = widget.task?.projectId ?? widget.projectId;
  late int? _assigneeId = widget.task?.assigneeId;
  late TaskPriority _priority = widget.task?.priority ?? TaskPriority.medium;
  late DateTime? _deadline = widget.task?.deadline;
  bool _saving = false;

  List<Project> _projects = [];
  List<User> _members = [];

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    context.read<ProjectRepository>().getProjects().then((p) {
      if (mounted) setState(() => _projects = p);
    });
    _loadMembers();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    if (_projectId == null) return setState(() => _members = []);
    final m = await context.read<ProjectRepository>().getMembers(_projectId!);
    if (!mounted) return;
    setState(() {
      _members = m;
      if (_assigneeId != null && !m.any((u) => u.id == _assigneeId))
        _assigneeId = null;
    });
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _deadline = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<TaskRepository>();
    final actor = context.read<AppState>().currentUserId;
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    final ok = await runGuarded(context, () async {
      if (_isEdit) {
        final t = widget.task!;
        await repo.updateTask(
          t.id,
          title: _title.text,
          description: _description.text,
          priority: _priority,
          deadline: _deadline,
        );
        if (_assigneeId != t.assigneeId)
          await repo.reassign(t.id, _assigneeId, actorId: actor);
      } else {
        await repo.createTask(
          TaskDraft(
            projectId: _projectId,
            title: _title.text,
            description: _description.text,
            assigneeId: _assigneeId,
            priority: _priority,
            deadline: _deadline,
          ),
          actorId: actor,
        );
      }
    }, success: _isEdit ? 'Задача сохранена' : 'Задача создана');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      title: _isEdit ? 'Редактирование' : 'Новая задача',
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Название',
                prefixIcon: Icon(Icons.title),
              ),
              validator: Validators.form(
                (v) => Validators.requireText(v, 'Название', max: 200),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Описание',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _projectId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Проект',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              items: [
                for (final p in _projects)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: _isEdit || widget.projectId != null
                  ? null
                  : (v) {
                      setState(() => _projectId = v);
                      _loadMembers();
                    },
              validator: (v) =>
                  v == null ? 'Задача должна принадлежать проекту' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              key: ValueKey('assignee-$_projectId-${_members.length}'),
              initialValue: _assigneeId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Исполнитель',
                prefixIcon: const Icon(Icons.person_outline),
                helperText: _projectId == null
                    ? 'Сначала выберите проект'
                    : 'Только участники проекта',
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Не назначен'),
                ),
                for (final u in _members)
                  DropdownMenuItem(value: u.id, child: Text(u.name)),
              ],
              onChanged: (v) => setState(() => _assigneeId = v),
            ),
            const SizedBox(height: 16),
            const Text(
              'Приоритет',
              style: TextStyle(color: Tf.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final p in TaskPriority.values)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: _priority == p,
                    showCheckmark: false,
                    selectedColor: Tf.priorityColor(p),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: _priority == p ? Colors.transparent : Tf.border,
                    ),
                    labelStyle: TextStyle(
                      color: _priority == p ? Colors.white : Tf.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _priority = p),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event, color: Tf.pink),
                title: const Text('Дедлайн'),
                subtitle: Text(
                  _deadline == null ? 'Не задан' : fmtDate(_deadline),
                ),
                trailing: _deadline == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _deadline = null),
                      ),
                onTap: _pickDeadline,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(_isEdit ? 'Сохранить' : 'Создать задачу'),
            ),
          ],
        ),
      ),
    );
  }
}
