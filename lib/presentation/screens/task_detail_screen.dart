import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../models/enums.dart';
import '../../models/view_models.dart';
import '../../repositories/comment_repository.dart';
import '../../repositories/task_repository.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/user_picker.dart';
import 'task_form_screen.dart';

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final int taskId;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TaskRepository>();
    return StreamBuilder<TaskItem?>(
      stream: repo.watchTask(taskId),
      builder: (context, snap) {
        final item = snap.data;
        if (item == null || item.task.deletedAt != null) {
          return GradientScaffold(
            title: 'Задача',
            body: snap.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : const EmptyState(
                    icon: Icons.delete_outline,
                    text: 'Задача удалена или не найдена',
                  ),
          );
        }
        return DefaultTabController(
          length: 3,
          child: GradientScaffold(
            title: item.task.title,
            subtitle: item.projectName,
            actions: [
              IconButton(
                tooltip: 'Редактировать',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TaskFormScreen(task: item.task),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'В корзину',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final ok = await runGuarded(
                    context,
                    () => repo.softDelete(taskId),
                    success: 'Задача перемещена в корзину',
                  );
                  if (ok) nav.pop();
                },
              ),
            ],
            body: NestedScrollView(
              headerSliverBuilder: (_, _) => [
                SliverToBoxAdapter(child: _TaskHeader(item: item)),
                const SliverToBoxAdapter(
                  child: TabBar(
                    tabs: [
                      Tab(text: 'Комментарии'),
                      Tab(text: 'Вложения'),
                      Tab(text: 'История'),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _CommentsTab(taskId: taskId),
                  _AttachmentsTab(taskId: taskId),
                  _HistoryTab(taskId: taskId),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TaskHeader extends StatelessWidget {
  const _TaskHeader({required this.item});

  final TaskItem item;

  Future<void> _changeStatus(BuildContext context, TaskStatus status) async {
    final repo = context.read<TaskRepository>();
    final actor = context.read<AppState>().currentUserId;
    final messenger = ScaffoldMessenger.of(context);
    final from = item.task.status;
    final ok = await runGuarded(
      context,
      () => repo.changeStatus(item.task.id, status, actorId: actor),
    );
    if (!ok) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Статус: ${from.label} → ${status.label}'),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () =>
              repo.undoLastStatusChange(item.task.id, actorId: actor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = item.task;
    final repo = context.read<TaskRepository>();
    final actor = context.watch<AppState>().currentUserId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (t.description.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t.description,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Статус',
            style: TextStyle(color: Tf.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in TaskStatus.values)
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  labelPadding: const EdgeInsets.only(left: 2, right: 4),
                  avatar: Icon(
                    Tf.statusIcon(s),
                    size: 16,
                    color: s == t.status ? Colors.white : Tf.statusColor(s),
                  ),
                  label: Text(s.label),
                  selected: s == t.status,
                  showCheckmark: false,
                  selectedColor: Tf.statusColor(s),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: s == t.status ? Colors.transparent : Tf.border,
                  ),
                  labelStyle: TextStyle(
                    color: s == t.status ? Colors.white : Tf.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  onSelected: (_) => _changeStatus(context, s),
                ),
            ],
          ),
          FutureBuilder<bool>(
            // пересчитываем при каждом изменении задачи
            key: ValueKey(t.updatedAt),
            future: repo.canUndo(t.id),
            builder: (context, snap) => snap.data == true
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Tf.pink),
                      onPressed: () => runGuarded(
                        context,
                        () => repo.undoLastStatusChange(t.id, actorId: actor),
                        success: 'Последнее изменение статуса отменено',
                      ),
                      icon: const Icon(Icons.undo),
                      label: const Text('Отменить последнее изменение статуса'),
                    ),
                  )
                : const SizedBox(height: 8),
          ),
          Card(
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Приоритет',
                  child: PriorityPill(
                    t.priority,
                    onTap: () async {
                      final p = await pickOption<TaskPriority>(
                        context,
                        title: 'Приоритет',
                        options: TaskPriority.values,
                        label: (p) => p.label,
                        selected: t.priority,
                        leading: (p) => Icon(
                          Icons.circle,
                          size: 14,
                          color: Tf.priorityColor(p),
                        ),
                      );
                      if (p != null && context.mounted) {
                        await runGuarded(
                          context,
                          () => repo.changePriority(t.id, p),
                        );
                      }
                    },
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Исполнитель',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      final r = await pickUser(
                        context,
                        title: 'Назначить исполнителя',
                        projectId: t.projectId,
                        noneLabel: 'Снять исполнителя',
                      );
                      if (r != null && context.mounted) {
                        await runGuarded(
                          context,
                          () => repo.reassign(t.id, r.user?.id, actorId: actor),
                          success: 'Исполнитель изменён',
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.assignee != null) ...[
                          UserAvatar(
                            name: item.assignee!.name,
                            id: item.assignee!.id,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          item.assignee?.name ?? 'Не назначен',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Tf.blue,
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 18, color: Tf.blue),
                      ],
                    ),
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                _InfoRow(
                  icon: Icons.event,
                  label: 'Дедлайн',
                  child: Text(
                    fmtDate(t.deadline),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: item.isOverdue ? Tf.pink : Tf.ink,
                    ),
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                _InfoRow(
                  icon: Icons.add_circle_outline,
                  label: 'Создана',
                  child: Text(fmtDateTime(t.createdAt)),
                ),
                const Divider(indent: 16, endIndent: 16),
                _InfoRow(
                  icon: Icons.update,
                  label: 'Изменена',
                  child: Text(fmtDateTime(t.updatedAt)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Tf.blue),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Tf.muted)),
          const Spacer(),
          child,
        ],
      ),
    );
  }
}

// ---------------- Комментарии ----------------

class _CommentsTab extends StatefulWidget {
  const _CommentsTab({required this.taskId});

  final int taskId;

  @override
  State<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<_CommentsTab> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final actor = context.read<AppState>().currentUserId;
    if (actor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите текущего пользователя')),
      );
      return;
    }
    final ok = await runGuarded(
      context,
      () => context.read<CommentRepository>().addComment(
        widget.taskId,
        actor,
        _text.text,
      ),
    );
    if (ok) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CommentRepository>();
    final me = context.watch<AppState>().currentUserId;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<CommentItem>>(
            stream: repo.watchComments(widget.taskId),
            builder: (context, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.chat_bubble_outline,
                  text: 'Комментариев пока нет',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final c = list[i];
                  final mine = c.author.id == me;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(
                        name: c.author.name,
                        id: c.author.id,
                        size: 34,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
                          decoration: BoxDecoration(
                            color: mine ? Tf.pinkSoft : Colors.white,
                            border: Border.all(
                              color: mine ? Colors.transparent : Tf.border,
                            ),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(18),
                              bottomLeft: Radius.circular(18),
                              bottomRight: Radius.circular(18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.author.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    fmtDateTime(c.comment.createdAt),
                                    style: const TextStyle(
                                      color: Tf.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (mine)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Удалить',
                                      icon: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Tf.pink,
                                      ),
                                      onPressed: () => runGuarded(
                                        context,
                                        () => repo.deleteComment(
                                          c.comment.id,
                                          actorId: me!,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Text(c.comment.body),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Написать комментарий…',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Tf.pink),
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- Вложения ----------------

class _AttachmentsTab extends StatelessWidget {
  const _AttachmentsTab({required this.taskId});

  final int taskId;

  Future<void> _add(BuildContext context) async {
    final repo = context.read<CommentRepository>();
    final file = await FilePicker.pickFile();
    if (file == null || !context.mounted) return;
    // В базе сохраняется только путь к файлу
    await runGuarded(
      context,
      () => repo.addAttachment(
        taskId,
        fileName: file.name,
        filePath: file.path ?? file.name,
      ),
      success: 'Файл прикреплён',
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CommentRepository>();
    return StreamBuilder<List<Attachment>>(
      stream: repo.watchAttachments(taskId),
      builder: (context, snap) {
        final list = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OutlinedButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.attach_file),
              label: const Text('Прикрепить файл'),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                  child: Text(
                    'Вложений нет',
                    style: TextStyle(color: Tf.muted),
                  ),
                ),
              ),
            for (final a in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Tf.blueSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.insert_drive_file_outlined,
                        color: Tf.blue,
                      ),
                    ),
                    title: Text(
                      a.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${fmtDateTime(a.addedAt)}\n${a.filePath}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Tf.pink),
                      onPressed: () => repo.deleteAttachment(a.id),
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

// ---------------- История ----------------

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.taskId});

  final int taskId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HistoryItem>>(
      stream: context.read<TaskRepository>().watchHistory(taskId),
      builder: (context, snap) {
        final list = snap.data ?? [];
        if (list.isEmpty)
          return const EmptyState(icon: Icons.history, text: 'История пуста');
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final h = list[i].entry;
            final user = list[i].user;
            final color = switch (h.event) {
              HistoryEvent.created => Tf.blue,
              HistoryEvent.statusChanged => Tf.statusColor(h.newStatus),
              HistoryEvent.assigneeChanged => Tf.orange,
              HistoryEvent.undo => Tf.pink,
            };
            final text = switch (h.event) {
              HistoryEvent.created =>
                'Создана со статусом «${h.newStatus.label}»',
              HistoryEvent.statusChanged =>
                '${h.oldStatus?.label ?? '—'} → ${h.newStatus.label}',
              HistoryEvent.assigneeChanged => h.details ?? '',
              HistoryEvent.undo =>
                '${h.oldStatus?.label ?? '—'} → ${h.newStatus.label}',
            };
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      if (i != list.length - 1)
                        Expanded(child: Container(width: 2, color: Tf.border)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                h.event.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                              if (h.reverted) ...[
                                const SizedBox(width: 6),
                                const Pill(label: 'отменено', color: Tf.muted),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(text),
                          if (h.event == HistoryEvent.undo && h.details != null)
                            Text(
                              h.details!,
                              style: const TextStyle(
                                color: Tf.muted,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            '${user?.name ?? 'Система'} · ${fmtDateTime(h.changedAt)}',
                            style: const TextStyle(
                              color: Tf.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
