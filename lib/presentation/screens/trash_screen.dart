import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/view_models.dart';
import '../../repositories/task_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/task_card.dart';

/// Корзина: удалённые задачи (soft delete) — восстановление или полное удаление.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TaskRepository>();
    return StreamBuilder<List<TaskItem>>(
      stream: repo.watchTrash(),
      builder: (context, snap) {
        final list = snap.data ?? [];
        return GradientScaffold(
          title: 'Корзина',
          subtitle: 'Удалённые задачи: ${list.length}',
          actions: [
            if (list.isNotEmpty)
              IconButton(
                tooltip: 'Очистить корзину',
                icon: const Icon(Icons.delete_forever_outlined),
                onPressed: () async {
                  if (await confirm(
                    context,
                    'Очистить корзину?',
                    'Задачи будут удалены навсегда.',
                  )) {
                    await repo.emptyTrash();
                  }
                },
              ),
          ],
          body: !snap.hasData
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
              ? const EmptyState(
                  icon: Icons.delete_outline,
                  text: 'Корзина пуста',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final item = list[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TaskCard(item: item, onTap: () {}),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Text(
                                'Удалена ${fmtDateTime(item.task.deletedAt!)}',
                                style: const TextStyle(
                                  color: Tf.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => runGuarded(
                                  context,
                                  () => repo.restore(item.task.id),
                                  success: 'Задача восстановлена',
                                ),
                                icon: const Icon(Icons.restore),
                                label: const Text('Восстановить'),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Tf.pink,
                                ),
                                onPressed: () async {
                                  if (await confirm(
                                    context,
                                    'Удалить навсегда?',
                                    'Комментарии, вложения и история задачи тоже будут удалены.',
                                  )) {
                                    await repo.deleteForever(item.task.id);
                                  }
                                },
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('Навсегда'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}
