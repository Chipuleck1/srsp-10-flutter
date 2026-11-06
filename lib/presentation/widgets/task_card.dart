import 'package:flutter/material.dart';

import '../../models/view_models.dart';
import '../theme.dart';
import 'common.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.item,
    required this.onTap,
    this.trailing,
    this.showProject = true,
  });

  final TaskItem item;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final t = item.task;
    final priorityColor = Tf.priorityColor(t.priority);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: priorityColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: Tf.ink,
                                decoration: t.status.isOpen
                                    ? null
                                    : TextDecoration.lineThrough,
                                decorationColor: Tf.muted,
                              ),
                            ),
                          ),
                          ?trailing,
                        ],
                      ),
                      if (showProject) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.projectName,
                          style: const TextStyle(
                            color: Tf.muted,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusPill(t.status),
                          PriorityPill(t.priority),
                          if (t.deadline != null)
                            Pill(
                              label: fmtDate(t.deadline),
                              icon: item.isOverdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.event,
                              color: item.isOverdue ? Tf.pink : Tf.muted,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (item.assignee != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 12),
                  child: Tooltip(
                    message: item.assignee!.name,
                    child: UserAvatar(
                      name: item.assignee!.name,
                      id: item.assignee!.id,
                      size: 32,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
