import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/dio_client.dart';
import 'data/local/post_cache.dart';
import 'data/remote/post_api.dart';
import 'data/repositories/post_repository.dart';
import 'presentation/screens/post_list_screen.dart';
import 'presentation/state/post_list_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Слои создаются один раз: Dio -> Retrofit API -> Repository -> UI
  final dioClient = DioClient();
  final repository = PostRepository(PostApi(dioClient.dio), PostCache(prefs));

  runApp(PostExplorerApp(repository: repository));
}

class PostExplorerApp extends StatelessWidget {
  const PostExplorerApp({super.key, required this.repository});

  final PostRepository repository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: repository),
        ChangeNotifierProvider(
          create: (_) => PostListNotifier(repository)..init(),
        ),
      ],
      child: MaterialApp(
        title: 'Post Explorer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        home: const PostListScreen(),
      ),
    );
  }
}
