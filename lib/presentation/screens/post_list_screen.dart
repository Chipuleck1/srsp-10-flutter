import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/post_list_notifier.dart';
import '../widgets/post_tile.dart';
import '../widgets/state_views.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

class PostListScreen extends StatefulWidget {
  const PostListScreen({super.key});

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      context.read<PostListNotifier>().loadNextPage();
    }
  }

  Future<void> _refresh() async {
    final notifier = context.read<PostListNotifier>();
    await notifier.refresh();
    if (!mounted) return;
    if (notifier.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось обновить: ${notifier.errorMessage}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PostListNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Explorer'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: state.isRefreshing ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreatePostScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Новый пост'),
      ),
      body: Column(
        children: [
          _Filters(searchController: _searchController),
          if (state.status == ListStatus.cached) _CacheBanner(state: state),
          if (state.isRefreshing) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildBody(PostListNotifier state) {
    switch (state.status) {
      case ListStatus.loading:
        return const LoadingView();
      case ListStatus.error:
        return ErrorView(
          message: state.errorMessage ?? 'Ошибка',
          onRetry: state.loadFirstPage,
        );
      case ListStatus.success:
      case ListStatus.cached:
        final posts = state.visiblePosts;
        if (posts.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                EmptyView(
                  message: state.query.isNotEmpty
                      ? 'По запросу «${state.query}» среди загруженных постов ничего не найдено'
                      : 'Постов нет',
                  action: state.hasActiveFilters
                      ? TextButton(
                          onPressed: () {
                            _searchController.clear();
                            state.resetFilters();
                          },
                          child: const Text('Сбросить фильтры'),
                        )
                      : null,
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: posts.length + 1,
            itemBuilder: (context, i) {
              if (i == posts.length) return _PageFooter(state: state);
              final post = posts[i];
              return PostTile(
                post: post,
                authorName: state.userById(post.userId)?.name,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(post: post),
                  ),
                ),
              );
            },
          ),
        );
    }
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.searchController});

  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PostListNotifier>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: state.setQuery,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Поиск по заголовку',
              helperText:
                  'Ищем только среди загруженных постов (${state.loadedCount} шт.)',
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: state.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        state.setQuery('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: state.authorId,
                  key: ValueKey(
                    'author-${state.authorId}-${state.users.length}',
                  ),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Автор',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Все посты'),
                    ),
                    ...state.users.map(
                      (u) => DropdownMenuItem(
                        value: u.id,
                        child: Text('${u.id}. ${u.name}'),
                      ),
                    ),
                  ],
                  onChanged: state.setAuthor,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: state.toggleSort,
                icon: Icon(
                  state.sortDesc ? Icons.arrow_downward : Icons.arrow_upward,
                ),
                label: const Text('ID'),
              ),
              IconButton(
                tooltip: 'Сбросить фильтры',
                onPressed: state.hasActiveFilters
                    ? () {
                        searchController.clear();
                        state.resetFilters();
                      }
                    : null,
                icon: const Icon(Icons.filter_alt_off),
              ),
            ],
          ),
          if (state.usersError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Авторы не загружены: ${state.usersError}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _CacheBanner extends StatelessWidget {
  const _CacheBanner({required this.state});

  final PostListNotifier state;

  @override
  Widget build(BuildContext context) {
    final t = state.cacheSavedAt;
    final time = t == null
        ? ''
        : ' от ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final text = state.isRefreshing
        ? 'Показаны сохранённые данные$time. Обновляем…'
        : 'Показаны сохранённые данные$time. ${state.errorMessage ?? ''}';

    return MaterialBanner(
      backgroundColor: Colors.amber.shade100,
      leading: const Icon(Icons.offline_pin),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: state.isRefreshing ? null : state.refresh,
          child: const Text('Обновить'),
        ),
      ],
    );
  }
}

class _PageFooter extends StatelessWidget {
  const _PageFooter({required this.state});

  final PostListNotifier state;

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (state.pageStatus) {
      case PageStatus.loading:
        child = const CircularProgressIndicator();
      case PageStatus.error:
        child = Column(
          children: [
            Text(
              'Не удалось загрузить страницу: ${state.pageErrorMessage}',
              textAlign: TextAlign.center,
            ),
            TextButton.icon(
              onPressed: state.loadNextPage,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        );
      case PageStatus.noMore:
        child = Text(
          state.status == ListStatus.cached
              ? 'Подгрузка недоступна, пока нет свежих данных'
              : 'Больше постов нет',
          style: const TextStyle(color: Colors.grey),
        );
      case PageStatus.idle:
        child = state.status == ListStatus.success
            ? TextButton(
                onPressed: state.loadNextPage,
                child: const Text('Загрузить ещё'),
              )
            : const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(child: child),
    );
  }
}
