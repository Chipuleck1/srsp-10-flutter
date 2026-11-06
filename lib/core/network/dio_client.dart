import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_interceptor.dart';

/// Единственный экземпляр Dio на всё приложение.
class DioClient {
  DioClient({HttpClientAdapter? adapter, bool enableRetry = true})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      ) {
    // adapter подменяется в тестах, чтобы не ходить в реальный интернет
    if (adapter != null) dio.httpClientAdapter = adapter;

    dio.interceptors.addAll([
      if (enableRetry) RetryInterceptor(dio),
      ApiInterceptor(),
      if (kDebugMode)
        LogInterceptor(
          requestBody: true,
          responseBody: false,
          logPrint: (o) => debugPrint(o.toString()),
        ),
    ]);
  }

  static const baseUrl = 'https://jsonplaceholder.typicode.com';

  final Dio dio;
}
