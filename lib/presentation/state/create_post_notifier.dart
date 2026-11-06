import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';

enum SubmitStatus { idle, submitting, success, error }

class CreatePostNotifier extends ChangeNotifier {
  CreatePostNotifier(this._repository);

  final PostRepository _repository;

  SubmitStatus status = SubmitStatus.idle;
  Post? createdPost;
  String? errorMessage;

  bool get isSubmitting => status == SubmitStatus.submitting;

  static String? validateTitle(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Введите заголовок';
    if (t.length < 5) return 'Минимум 5 символов';
    if (t.length > 100) return 'Максимум 100 символов';
    return null;
  }

  static String? validateBody(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Введите текст поста';
    if (t.length < 10) return 'Минимум 10 символов';
    if (t.length > 1000) return 'Максимум 1000 символов';
    return null;
  }

  static String? validateUser(int? v) => v == null ? 'Выберите автора' : null;

  Future<Post?> submit(CreatePostRequest request) async {
    if (isSubmitting) return null; // защита от двойного нажатия
    status = SubmitStatus.submitting;
    errorMessage = null;
    notifyListeners();
    try {
      createdPost = await _repository.createPost(request);
      status = SubmitStatus.success;
      return createdPost;
    } on AppException catch (e) {
      errorMessage = e.message;
      status = SubmitStatus.error;
      return null;
    } finally {
      notifyListeners();
    }
  }
}
