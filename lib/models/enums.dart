/// Статус проекта.
enum ProjectStatus {
  active('Активный'),
  completed('Завершённый'),
  archived('Архивный');

  const ProjectStatus(this.label);
  final String label;
}

/// Роль участника проекта.
enum MemberRole {
  owner('Owner'),
  admin('Admin'),
  member('Member');

  const MemberRole(this.label);
  final String label;
}

/// Статус задачи.
enum TaskStatus {
  todo('Ожидает'),
  inProgress('В работе'),
  done('Завершена'),
  cancelled('Отменена');

  const TaskStatus(this.label);
  final String label;

  bool get isOpen => this == todo || this == inProgress;
}

/// Приоритет задачи.
enum TaskPriority {
  low('Низкий'),
  medium('Средний'),
  high('Высокий'),
  critical('Критический');

  const TaskPriority(this.label);
  final String label;
}

/// Тип события в истории задачи.
enum HistoryEvent {
  created('Создана'),
  statusChanged('Смена статуса'),
  assigneeChanged('Смена исполнителя'),
  undo('Отмена изменения');

  const HistoryEvent(this.label);
  final String label;
}
