import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/secure_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorage extends Mock implements SecureStorageService {}

/// Scripted HTTP layer. Routes are keyed by `"METHOD path"` and answer with a
/// JSON body (or any [ResponseBody]); every request is recorded.
class FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, Future<ResponseBody> Function(RequestOptions)> _routes = {};

  void on(String route, Object? body, {int status = 200}) {
    _routes[route] = (_) async => jsonBody(body, status);
  }

  void onError(String route, int status, [Object? body]) {
    _routes[route] = (_) async => jsonBody(body ?? {'detail': 'error'}, status);
  }

  void onCall(
    String route,
    Future<ResponseBody> Function(RequestOptions) handler,
  ) {
    _routes[route] = handler;
  }

  RequestOptions get last => requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    final handler = _routes['${options.method} ${options.path}'];
    if (handler == null) {
      return Future.value(jsonBody({'detail': 'no route'}, 404));
    }
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object? body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// An [ApiClient] whose network layer is [adapter] and whose token storage is
/// an empty mock (no Authorization header is attached).
ApiClient fakeApiClient(FakeAdapter adapter, {MockSecureStorage? storage}) {
  final secure = storage ?? MockSecureStorage();
  if (storage == null) {
    when(() => secure.getAccessToken()).thenAnswer((_) async => null);
  }
  final client = ApiClient(secureStorage: secure);
  client.dio.httpClientAdapter = adapter;
  return client;
}

Map<String, dynamic> userJson({String id = 'u1', String name = 'ana'}) => {
  'id': id,
  'username': name,
  'full_name': 'Ana Quena',
  'avatar_url': null,
};

Map<String, dynamic> postJson({String id = 'p1'}) => {
  'id': id,
  'user': userJson(),
  'content': 'Practicando quena',
  'post_type': 'text',
  'likes_count': 2,
  'comments_count': 1,
  'is_liked_by_me': false,
  'created_at': '2026-11-17T10:00:00Z',
};

Map<String, dynamic> commentJson({String id = 'c1'}) => {
  'id': id,
  'post_id': 'p1',
  'user': userJson(),
  'content': 'Bravo',
  'created_at': '2026-11-17T10:00:00Z',
};

Map<String, dynamic> pageJson(List<Map<String, dynamic>> items) => {
  'items': items,
  'next_cursor': 'next',
  'has_more': true,
  'total': items.length,
  'page': 1,
  'pages': 1,
};
