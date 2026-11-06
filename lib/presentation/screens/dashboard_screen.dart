import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/view_models.dart';
import '../../repositories/stats_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'project_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      title: 'TaskFlow',
      subtitle: 'Статистика по всем проектам',
      actions: actions,
      body: StreamBuilder<DashboardStats>(
        stream: context.read<StatsRepository>().watchDashboard(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final s = snap.data!;
          final percent = s.tasks == 0 ? 0.0 : s.done / s.tasks;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _HeroCard(percent: percent, done: s.done, total: s.tasks),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.7,
                children: [
                  _StatTile(
                    icon: Icons.folder_outlined,
                    label: 'Проекты',
                    value: s.projects,
                    color: Tf.blue,
                  ),
                  _StatTile(
                    icon: Icons.list_alt,
                    label: 'Задачи',
                    value: s.tasks,
                    color: Tf.pink,
                  ),
                  _StatTile(
                    icon: Icons.check_circle_outline,
                    label: 'Завершено',
                    value: s.done,
                    color: Tf.green,
                  ),
                  _StatTile(
                    icon: Icons.timelapse,
                    label: 'Не завершено',
                    value: s.open,
                    color: Tf.blue,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _OverdueBanner(count: s.overdue),
              const SectionTitle('Задачи по приоритетам'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final p in TaskPriority.values.reversed)
                        _BarRow(
                          label: p.label,
                          value: s.byPriority[p] ?? 0,
                          max: s.tasks,
                          color: Tf.priorityColor(p),
                        ),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Задачи у исполнителей'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: s.byAssignee.isEmpty
                      ? const Text(
                          'Нет задач',
                          style: TextStyle(color: Tf.muted),
                        )
                      : Column(
                          children: [
                            for (final a in s.byAssignee.take(10))
                              _BarRow(
                                label: a.name,
                                value: a.count,
                                max: s.byAssignee.first.count,
                                color: a.userId == null ? Tf.muted : Tf.blue,
                              ),
                            if (s.byAssignee.length > 10)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'и ещё ${s.byAssignee.length - 10} исполнителей',
                                  style: const TextStyle(
                                    color: Tf.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              SectionTitle(
                'Выполнение проектов',
                trailing: Text('${s.projectProgress.length}'),
              ),
              if (s.projectProgress.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Проектов нет'),
                  ),
                ),
              for (final p in s.projectProgress.take(30))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProjectDetailScreen(projectId: p.projectId),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${p.done}/${p.total}',
                                  style: const TextStyle(
                                    color: Tf.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${p.percent.round()}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Tf.pink,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            GradientProgress(value: p.percent / 100),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.percent,
    required this.done,
    required this.total,
  });

  final double percent;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: Tf.gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Tf.pink.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            height: 86,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 9,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '${(percent * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Общий прогресс',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  '$done из $total задач',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'завершено',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: Tf.muted, fontSize: 13),
                  ),
                ),
              ],
            ),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverdueBanner extends StatelessWidget {
  const _OverdueBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: count > 0 ? Tf.pinkSoft : Tf.blueSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            count > 0 ? Icons.warning_amber_rounded : Icons.verified_outlined,
            color: count > 0 ? Tf.pink : Tf.blue,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count > 0
                  ? 'Просроченных задач: $count'
                  : 'Просроченных задач нет',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: count > 0 ? Tf.pink : Tf.blue,
                fontSize: 15,
              ),
            ),
          ),
          if (count > 0)
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Tf.pink,
              ),
            ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final f = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(height: 12, color: Tf.blueSoft),
                  FractionallySizedBox(
                    widthFactor: f.clamp(0, 1),
                    child: Container(height: 12, color: color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
