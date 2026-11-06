import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/comment.dart';
import '../../data/models/post.dart';
import '../../data/models/user.dart';
import '../../data/repositories/post_repository.dart';
import '../state/post_detail_notifier.dart';
import '../state/post_list_notifier.dart';
import '../state/view_state.dart';
import '../widgets/state_views.dart';

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          PostDetailNotifier(ctx.read<PostRepository>(), post)..load(),
      child: const _PostDetailView(),
    );
  }
}

class _PostDetailView extends StatelessWidget {
  const _PostDetailView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PostDetailNotifier>();

    return Scaffold(
      appBar: AppBar(title: Text('Пост #${state.initialPost.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section<Post>(
            state.post,
            onRetry: state.retryPost,
            builder: (post) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.isLocal) ...[
                  const LocalBadge(),
                  const SizedBox(height: 4),
                  const Text(
                    'JSONPlaceholder не сохраняет созданные посты, '
                    'поэтому он есть только в этом приложении.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(post.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(post.body),
              ],
            ),
          ),
          const Divider(height: 32),
          Text('Автор', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _section<User>(
            state.author,
            onRetry: state.retryAuthor,
            builder: (user) => _AuthorCard(user: user),
          ),
          const Divider(height: 32),
          Text('Комментарии', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _section<List<Comment>>(
            state.comments,
            onRetry: state.retryComments,
            builder: (comments) => comments.isEmpty
                ? const Text(
                    'Комментариев нет',
                    style: TextStyle(color: Colors.grey),
                  )
                : Column(
                    children: comments
                        .map(
                          (c) => Card(
                            child: ListTile(
                              title: Text(c.name),
                              subtitle: Text('${c.email ?? ''}\n${c.body}'),
                              isThreeLine: true,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _section<T>(
    ViewState<T> s, {
    required VoidCallback onRetry,
    required Widget Function(T) builder,
  }) {
    return switch (s) {
      ViewLoading() => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      ViewError(:final message) => Row(
        children: [
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
      ViewSuccess(:final data) => builder(data),
    };
  }
}

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final address = user.address;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (user.email != null) Text(user.email!),
            if (address?.city != null)
              Text(
                'Город: ${address!.city}'
                '${address.geo?.lat != null ? ' (${address.geo!.lat}, ${address.geo!.lng})' : ''}',
              ),
            if (user.company != null) Text('Компания: ${user.company!.name}'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                context.read<PostListNotifier>().setAuthor(user.id);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.person_search),
              label: const Text('Все посты автора'),
            ),
          ],
        ),
      ),
    );
  }
}
