import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';
import '../state/create_post_notifier.dart';
import '../state/post_list_notifier.dart';
import '../widgets/state_views.dart';

class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CreatePostNotifier(ctx.read<PostRepository>()),
      child: const _CreatePostForm(),
    );
  }
}

class _CreatePostForm extends StatefulWidget {
  const _CreatePostForm();

  @override
  State<_CreatePostForm> createState() => _CreatePostFormState();
}

class _CreatePostFormState extends State<_CreatePostForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  int? _userId;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = context.read<CreatePostNotifier>();
    final listNotifier = context.read<PostListNotifier>();

    final post = await notifier.submit(
      CreatePostRequest(
        userId: _userId!,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
      ),
    );
    if (!mounted) return;

    if (post != null) {
      listNotifier.addLocalPost(post);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пост создан и добавлен в список как локальный'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notifier.errorMessage ?? 'Ошибка')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CreatePostNotifier>();
    final users = context.watch<PostListNotifier>().users;

    return Scaffold(
      appBar: AppBar(title: const Text('Новый пост')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<int>(
              initialValue: _userId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Автор (userId)',
                border: OutlineInputBorder(),
              ),
              items: users
                  .map(
                    (u) => DropdownMenuItem(
                      value: u.id,
                      child: Text('${u.id}. ${u.name}'),
                    ),
                  )
                  .toList(),
              onChanged: state.isSubmitting
                  ? null
                  : (v) => setState(() => _userId = v),
              validator: CreatePostNotifier.validateUser,
            ),
            if (users.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Список авторов ещё не загружен',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              enabled: !state.isSubmitting,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Заголовок (5–100 символов)',
                border: OutlineInputBorder(),
              ),
              validator: CreatePostNotifier.validateTitle,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bodyController,
              enabled: !state.isSubmitting,
              maxLength: 1000,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Текст (10–1000 символов)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: CreatePostNotifier.validateBody,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              // Кнопка заблокирована, пока идёт запрос
              onPressed: state.isSubmitting ? null : _submit,
              icon: state.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(state.isSubmitting ? 'Отправка…' : 'Отправить'),
            ),
            if (state.status == SubmitStatus.error) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? '',
                style: const TextStyle(color: Colors.red),
              ),
            ],
            if (state.createdPost != null) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Ответ сервера',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 8),
                  const LocalBadge(),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  const JsonEncoder.withIndent('  ')
                      .convert(state.createdPost!.toJson()..remove('isLocal')),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'JSONPlaceholder только имитирует создание и не хранит пост '
                'на сервере, поэтому в списке он помечен «создан локально».',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
