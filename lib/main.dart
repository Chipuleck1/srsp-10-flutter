import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database/app_database.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/theme.dart';
import 'repositories/comment_repository.dart';
import 'repositories/performance_repository.dart';
import 'repositories/project_repository.dart';
import 'repositories/stats_repository.dart';
import 'repositories/task_repository.dart';
import 'repositories/user_repository.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Одна база на всё приложение: Database -> Repository -> State -> UI
  final db = AppDatabase();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: db),
        Provider(create: (_) => UserRepository(db)),
        Provider(create: (_) => ProjectRepository(db)),
        Provider(create: (_) => TaskRepository(db)),
        Provider(create: (_) => CommentRepository(db)),
        Provider(create: (_) => StatsRepository(db)),
        Provider(create: (_) => PerformanceRepository(db)),
        ChangeNotifierProvider(create: (_) => AppState(prefs)),
      ],
      child: const TaskFlowApp(),
    ),
  );
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: Tf.theme(),
      home: const HomeShell(),
    );
  }
}
