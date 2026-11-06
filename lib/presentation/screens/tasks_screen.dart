import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/task_repository.dart';
import '../../state/task_list_controller.dart';
import '../widgets/common.dart';
import '../widgets/task_list_view.dart';
import 'task_form_screen.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => TaskListController(ctx.read<TaskRepository>()),
      child: GradientScaffold(
        title: 'Задачи',
        subtitle: 'Все проекты',
        actions: actions,
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'tasks-fab',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TaskFormScreen()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Задача'),
        ),
        body: const TaskListView(),
      ),
    );
  }
}
