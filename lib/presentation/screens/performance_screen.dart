import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/performance_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Тест производительности: генерация 1000/100/10000 записей
/// и сравнение скорости запросов с индексами и без.
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  String? _busy;
  int? _taskCount;
  Duration? _seedTime;
  List<BenchmarkResult>? _results;

  PerformanceRepository get _repo => context.read<PerformanceRepository>();

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    final c = await _repo.countTasks();
    if (mounted) setState(() => _taskCount = c);
  }

  Future<void> _seed() async {
    final sw = Stopwatch()..start();
    setState(() => _busy = 'Генерация данных…');
    await _repo.seedLarge(
      onProgress: (s) => mounted ? setState(() => _busy = s) : null,
    );
    sw.stop();
    setState(() {
      _busy = null;
      _seedTime = sw.elapsed;
    });
    await _refreshCount();
  }

  Future<void> _bench() async {
    setState(() => _busy = 'Измеряем запросы…');
    final r = await _repo.runBenchmark();
    setState(() {
      _busy = null;
      _results = r;
    });
  }

  Future<void> _clear() async {
    if (!await confirm(
      context,
      'Удалить все данные?',
      'Будут удалены все пользователи, проекты и задачи.',
    ))
      return;
    setState(() => _busy = 'Удаление…');
    await _repo.clearAll();
    setState(() {
      _busy = null;
      _results = null;
    });
    await _refreshCount();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busy != null;
    return GradientScaffold(
      title: 'Производительность',
      subtitle: 'Индексы SQLite',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Тестовая база',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Добавляет 1 000 пользователей, 100 проектов (по 10 участников) и 10 000 задач.',
                    style: TextStyle(color: Tf.muted),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Сейчас задач в базе: ${_taskCount ?? '…'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (_seedTime != null)
                    Text(
                      'Генерация заняла ${(_seedTime!.inMilliseconds / 1000).toStringAsFixed(1)} с',
                      style: const TextStyle(color: Tf.muted),
                    ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: busy ? null : _seed,
                    icon: const Icon(Icons.dataset_outlined),
                    label: const Text('Сгенерировать данные'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Tf.pink),
            onPressed: busy ? null : _bench,
            icon: const Icon(Icons.speed),
            label: const Text('Сравнить: с индексами и без'),
          ),
          if (busy) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(
              color: Tf.pink,
              backgroundColor: Tf.pinkSoft,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(_busy!, style: const TextStyle(color: Tf.muted)),
            ),
          ],
          if (_results != null) ...[
            const SectionTitle('Среднее время запроса, мс'),
            for (final r in _results!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _Metric(
                                label: 'С индексами',
                                value: r.withIndexMs,
                                color: Tf.blue,
                              ),
                            ),
                            Expanded(
                              child: _Metric(
                                label: 'Без индексов',
                                value: r.withoutIndexMs,
                                color: Tf.pink,
                              ),
                            ),
                            Pill(
                              label: '×${r.speedup.toStringAsFixed(1)}',
                              color: r.speedup >= 1.2 ? Tf.green : Tf.muted,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Text(
              'Индексы ускоряют поиск по равенству, диапазону и сортировку. '
              'Поиск LIKE \'%…%\' по подстроке индекс не использует, поэтому время почти не меняется.',
              style: TextStyle(color: Tf.muted, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 28),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Tf.pink,
              side: const BorderSide(color: Tf.pink),
            ),
            onPressed: busy ? null : _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Удалить все данные'),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Tf.muted, fontSize: 12)),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
