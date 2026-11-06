import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';

/// Единый тип ошибок приложения.
/// [message] — понятный текст для пользователя,
/// [details] — технические подробности только для логов.
sealed class AppException implements Exception {
  const AppException(this.message, {this.details});

  final String message;
  final String? details;

  /// Преобразует любую ошибку (Dio, JSON, прочее) в [AppException].
  factory AppException.from(Object error) {
    if (error is AppException) return error;
    if (error is DioException) return AppException.fromDio(error);
    if (error is CheckedFromJsonException ||
        error is FormatException ||
        error is TypeError) {
      return ParsingException(details: error.toString());
    }
    return UnknownException(details: error.toString());
  }

  factory AppException.fromDio(DioException e) {
    final inner = e.error;
    if (inner is AppException) return inner;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutAppException(details: e.message);
      case DioExceptionType.connectionError:
        return NoConnectionException(details: e.message);
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        if (code >= 500) return ServerException(code, details: e.message);
        return ClientException(code, details: e.message);
      case DioExceptionType.cancel:
        return const CancelledException();
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        if (inner is FormatException ||
            inner is TypeError ||
            inner is CheckedFromJsonException) {
          return ParsingException(details: inner.toString());
        }
        return UnknownException(details: '${e.message} / $inner');
    }
  }

  @override
  String toString() => '$runtimeType: $message ${details ?? ''}';
}

class NoConnectionException extends AppException {
  const NoConnectionException({super.details})
    : super('Нет подключения к интернету');
}

class TimeoutAppException extends AppException {
  const TimeoutAppException({super.details})
    : super('Сервер не отвечает. Попробуйте ещё раз');
}

/// HTTP 4xx
class ClientException extends AppException {
  const ClientException(this.statusCode, {super.details})
    : super(
        statusCode == 404
            ? 'Данные не найдены (404)'
            : 'Некорректный запрос ($statusCode)',
      );

  final int statusCode;
}

/// HTTP 5xx
class ServerException extends AppException {
  const ServerException(this.statusCode, {super.details})
    : super('Ошибка сервера ($statusCode). Попробуйте позже');

  final int statusCode;
}

class ParsingException extends AppException {
  const ParsingException({super.details})
    : super('Сервер вернул некорректные данные');
}

class CancelledException extends AppException {
  const CancelledException() : super('Запрос отменён');
}

class UnknownException extends AppException {
  const UnknownException({super.details}) : super('Что-то пошло не так');
}
