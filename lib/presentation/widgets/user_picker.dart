import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../repositories/project_repository.dart';
import '../../repositories/user_repository.dart';
import '../theme.dart';
import 'common.dart';

/// Результат выбора пользователя: [user] == null означает «никто / все».
class UserChoice {
  const UserChoice(this.user);
  final User? user;
}

/// Выбор пользователя с поиском. Если задан [projectId] — только участники проекта.
/// [excludeProjectId] — скрыть уже состоящих в проекте (для добавления участника).
Future<UserChoice?> pickUser(
  BuildContext context, {
  required String title,
  int? projectId,
  int? excludeProjectId,
  String? noneLabel,
}) {
  return showModalBottomSheet<UserChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _UserPickerSheet(
      title: title,
      projectId: projectId,
      excludeProjectId: excludeProjectId,
      noneLabel: noneLabel,
    ),
  );
}

class _UserPickerSheet extends StatefulWidget {
  const _UserPickerSheet({
    required this.title,
    this.projectId,
    this.excludeProjectId,
    this.noneLabel,
  });

  final String title;
  final int? projectId;
  final int? excludeProjectId;
  final String? noneLabel;

  @override
  State<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<_UserPickerSheet> {
  String _search = '';
  late final Future<Set<int>> _excluded;
  late Stream<List<User>> _users;

  @override
  void initState() {
    super.initState();
    final projects = context.read<ProjectRepository>();
    _excluded = widget.excludeProjectId == null
        ? Future.value(<int>{})
        : projects
              .getMembers(widget.excludeProjectId!)
              .then((m) => m.map((u) => u.id).toSet());
    _load();
  }

  void _load() {
    if (widget.projectId != null) {
      final s = _search.toLowerCase();
      _users =
          Stream.fromFuture(
            context.read<ProjectRepository>().getMembers(widget.projectId!),
          ).map(
            (list) => list
                .where(
                  (u) =>
                      u.name.toLowerCase().contains(s) || u.email.contains(s),
                )
                .toList(),
          );
    } else {
      _users = context.read<UserRepository>().watchUsers(
        search: _search,
        limit: 100,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Имя или email',
                  ),
                  onChanged: (v) => setState(() {
                    _search = v.trim();
                    _load();
                  }),
                ),
              ],
            ),
          ),
          if (widget.noneLabel != null)
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Tf.blueSoft,
                child: Icon(Icons.people_outline, color: Tf.blue),
              ),
              title: Text(widget.noneLabel!),
              onTap: () => Navigator.pop(context, const UserChoice(null)),
            ),
          Expanded(
            child: FutureBuilder<Set<int>>(
              future: _excluded,
              builder: (context, ex) => StreamBuilder<List<User>>(
                stream: _users,
                builder: (context, snap) {
                  if (!snap.hasData || !ex.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final users = snap.data!
                      .where((u) => !ex.data!.contains(u.id))
                      .toList();
                  if (users.isEmpty) {
                    return const EmptyState(
                      icon: Icons.person_search,
                      text: 'Никого не найдено',
                    );
                  }
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (_, i) {
                      final u = users[i];
                      return ListTile(
                        leading: UserAvatar(name: u.name, id: u.id),
                        title: Text(u.name),
                        subtitle: Text(u.email),
                        onTap: () => Navigator.pop(context, UserChoice(u)),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
