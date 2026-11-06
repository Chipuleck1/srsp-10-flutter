/// Состояние одной асинхронной операции (детали поста, комментарии, автор).
sealed class ViewState<T> {
  const ViewState();
}

class ViewLoading<T> extends ViewState<T> {
  const ViewLoading();
}

class ViewSuccess<T> extends ViewState<T> {
  const ViewSuccess(this.data);
  final T data;
}

class ViewError<T> extends ViewState<T> {
  const ViewError(this.message);
  final String message;
}
