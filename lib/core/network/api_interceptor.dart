import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../error/app_exception.dart';

/// Добавляет технические заголовки и централизованно превращает
/// ошибки Dio в [AppException] (кладёт её в DioException.error).
class ApiInterceptor extends Interceptor {
  int _requestCounter = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.addAll({
      'Accept': 'application/json',
      'X-Client-Name': 'PostExplorer',
      'X-Client-Version': '1.0.0',
      'X-Request-Id':
          '${DateTime.now().millisecondsSinceEpoch}-${_requestCounter++}',
    });
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is AppException) return handler.next(err);

    final appException = AppException.fromDio(err);
    // Технические подробности — только в лог разработки
    debugPrint(
      '[API ERROR] ${err.requestOptions.method} '
      '${err.requestOptions.uri} -> ${appException.runtimeType}: '
      '${appException.details}',
    );
    handler.next(err.copyWith(error: appException));
  }
}

/// Повторяет GET-запросы при временных сетевых ошибках.
/// POST не повторяется автоматически, чтобы не создать пост дважды.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxRetries = 2});

  final Dio _dio;
  final int maxRetries;

  static const _attemptKey = 'retry_attempt';

  bool _shouldRetry(DioException err) {
    if (err.requestOptions.method != 'GET') return false;
    return err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;
    if (!_shouldRetry(err) || attempt >= maxRetries) {
      return handler.next(err);
    }

    await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    final options = err.requestOptions..extra[_attemptKey] = attempt + 1;
    debugPrint('[RETRY] ${options.uri} attempt ${attempt + 1}');
    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
