/// Ошибка бизнес-правила или проверки данных. [message] показывается пользователю.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

class DuplicateEmailException extends AppException {
  const DuplicateEmailException()
    : super('Пользователь с таким email уже существует');
}

class UserHasOpenTasksException extends AppException {
  const UserHasOpenTasksException(int count)
    : super('Нельзя удалить пользователя: за ним $count незавершённых задач');
}

class DuplicateMemberException extends AppException {
  const DuplicateMemberException()
    : super('Пользователь уже состоит в этом проекте');
}

class AssigneeNotMemberException extends AppException {
  const AssigneeNotMemberException()
    : super('Исполнитель должен быть участником проекта');
}

class AssigneeOverloadedException extends AppException {
  const AssigneeOverloadedException()
    : super('У исполнителя уже 3 незавершённые задачи с таким дедлайном');
}

class ForbiddenException extends AppException {
  const ForbiddenException(super.message);
}
