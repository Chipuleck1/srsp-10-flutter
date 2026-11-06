import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = Future<FakeResponse> Function(RequestOptions options);

class FakeResponse {
  const FakeResponse(this.body, {this.status = 200});
  final Object? body;
  final int status;
}

/// Mock-адаптер Dio: отвечает заранее подготовленными данными,
/// поэтому тесты не зависят от реального интернета.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FakeHandler handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final r = await handler(options);
    return ResponseBody.fromString(
      r.body is String ? r.body as String : jsonEncode(r.body),
      r.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

List<Map<String, dynamic>> fakePosts(int from, int count, {int userId = 1}) =>
    List.generate(
      count,
      (i) => {
        'id': from + i,
        'userId': userId,
        'title': 'Post ${from + i}',
        'body': 'Body ${from + i}',
      },
    );
