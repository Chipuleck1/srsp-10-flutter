import '../models/app_exception.dart';

/// Проверка корректности данных перед сохранением в базу.
abstract final class Validators {
  static final _emailRegExp = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String requireText(
    String? value,
    String field, {
    int min = 1,
    int max = 200,
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) throw ValidationException('Поле «$field» обязательно');
    if (v.length < min)
      throw ValidationException('«$field»: минимум $min символа');
    if (v.length > max)
      throw ValidationException('«$field»: максимум $max символов');
    return v;
  }

  static String email(String? value) {
    final v = value?.trim().toLowerCase() ?? '';
    if (!_emailRegExp.hasMatch(v)) {
      throw const ValidationException('Введите корректный email');
    }
    return v;
  }

  /// Форма-валидатор для TextFormField: возвращает текст ошибки или null.
  static String? Function(String?) form(void Function(String?) check) => (v) {
    try {
      check(v);
      return null;
    } on AppException catch (e) {
      return e.message;
    }
  };
}
