import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/app_database.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/validators.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'user_detail_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.actions});

  final List<Widget> actions;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _search = '';
  int _limit = 50;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<UserRepository>();
    return GradientScaffold(
      title: 'Пользователи',
      actions: widget.actions,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'users-fab',
        onPressed: () => showUserForm(context),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Пользователь'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: Tf.blue),
                hintText: 'Имя или email',
              ),
              onChanged: (v) => setState(() {
                _search = v;
                _limit = 50;
              }),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<User>>(
              stream: repo.watchUsers(search: _search, limit: _limit),
              builder: (context, snap) {
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());
                final list = snap.data!;
                if (list.isEmpty)
                  return const EmptyState(
                    icon: Icons.group_outlined,
                    text: 'Пользователей нет',
                  );
                final hasMore = list.length >= _limit;
                return NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (hasMore && n.metrics.extentAfter < 300)
                      setState(() => _limit += 50);
                    return false;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final u = list[i];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          leading: UserAvatar(name: u.name, id: u.id, size: 42),
                          title: Text(
                            u.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(u.email),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Tf.muted,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserDetailScreen(userId: u.id),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Создание или редактирование пользователя.
Future<int?> showUserForm(BuildContext context, {User? user}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _UserForm(user: user),
  );
}

class _UserForm extends StatefulWidget {
  const _UserForm({this.user});

  final User? user;

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name);
  late final _email = TextEditingController(text: widget.user?.email);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<UserRepository>();
    final nav = Navigator.of(context);
    int? id = widget.user?.id;
    final ok = await runGuarded(
      context,
      () async {
        if (widget.user == null) {
          id = await repo.createUser(name: _name.text, email: _email.text);
        } else {
          await repo.updateUser(
            widget.user!.id,
            name: _name.text,
            email: _email.text,
          );
        }
      },
      success: widget.user == null
          ? 'Пользователь создан'
          : 'Изменения сохранены',
    );
    if (ok) nav.pop(id);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.user == null ? 'Новый пользователь' : 'Редактирование',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Имя',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: Validators.form(
                (v) => Validators.requireText(v, 'Имя', max: 100),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: Validators.form(Validators.email),
            ),
            if (widget.user != null) ...[
              const SizedBox(height: 10),
              Text(
                'Дата регистрации: ${fmtDate(widget.user!.registeredAt)}',
                style: const TextStyle(color: Tf.muted),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Сохранить')),
          ],
        ),
      ),
    );
  }
}
