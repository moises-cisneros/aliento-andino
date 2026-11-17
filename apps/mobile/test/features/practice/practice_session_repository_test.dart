import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/features/practice/data/models/practice_session_model.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake HTTP layer: records requests and answers with a scripted behaviour.
class _FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Future<ResponseBody> Function(RequestOptions options) handler = (_) async =>
      _json(200, {'id': 'server-id'});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

PracticeSessionModel _session(String clientId) => PracticeSessionModel(
  lessonId: 'lesson-1',
  clientId: clientId,
  score: 80,
  correctNotes: 8,
  totalNotes: 10,
  wrongNotes: 1,
  missedNotes: 1,
  averageTempo: 70,
  totalTimeSeconds: 42,
);

void main() {
  late AppDatabase db;
  late _FakeAdapter adapter;
  late PracticeSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))
      ..httpClientAdapter = adapter;
    repo = PracticeSessionRepository(dio: dio, db: db);
  });

  tearDown(() async => db.close());

  test(
    'submit posts the session with its client_id to /v1/practice/session',
    () async {
      final outcome = await repo.submit(_session('cid-1'));

      expect(outcome.pending, isFalse);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, '/v1/practice/session');
      expect((adapter.requests.single.data as Map)['client_id'], 'cid-1');
      expect(await db.pendingCount(), 0);
    },
  );

  test('offline submit is queued with is_synced = false', () async {
    adapter.handler = (o) async => throw DioException(
      requestOptions: o,
      type: DioExceptionType.connectionError,
    );

    final outcome = await repo.submit(_session('cid-2'));

    expect(outcome.pending, isTrue);
    final rows = await db.getPendingPractices();
    expect(rows, hasLength(1));
    expect(rows.single.clientId, 'cid-2');
    expect(rows.single.isSynced, isFalse);
  });

  test('server rejection (4xx) is propagated and not queued', () async {
    adapter.handler = (o) async => _json(422, {'detail': 'invalid'});

    await expectLater(
      repo.submit(_session('cid-3')),
      throwsA(isA<DioException>()),
    );
    expect(await db.pendingCount(), 0);
  });

  test('syncPending drains the queue reusing the same client_id', () async {
    adapter.handler = (o) async => throw DioException(
      requestOptions: o,
      type: DioExceptionType.connectionError,
    );
    await repo.submit(_session('cid-4'));
    adapter.requests.clear();

    adapter.handler = (_) async => _json(200, {'id': 'server-id'});
    final synced = await repo.syncPending();

    expect(synced, 1);
    expect((adapter.requests.single.data as Map)['client_id'], 'cid-4');
    expect(await db.pendingCount(), 0);
    expect(await db.getPendingPractices(), isEmpty);
  });

  test('syncPending keeps items on transient errors (5xx and 404)', () async {
    adapter.handler = (o) async => throw DioException(
      requestOptions: o,
      type: DioExceptionType.connectionError,
    );
    await repo.submit(_session('cid-5'));

    for (final status in [503, 404]) {
      adapter.handler = (_) async => _json(status, {'detail': 'x'});
      expect(await repo.syncPending(), 0);
      expect(await db.pendingCount(), 1, reason: 'HTTP $status must retry');
    }
  });

  test('syncPending discards poison items (422)', () async {
    adapter.handler = (o) async => throw DioException(
      requestOptions: o,
      type: DioExceptionType.connectionError,
    );
    await repo.submit(_session('cid-6'));

    adapter.handler = (_) async => _json(422, {'detail': 'bad'});
    expect(await repo.syncPending(), 0);
    expect(await db.pendingCount(), 0);
  });
}
