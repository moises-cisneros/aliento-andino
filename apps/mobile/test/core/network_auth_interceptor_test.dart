import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_api.dart';

void main() {
  late FakeAdapter adapter;
  late MockSecureStorage storage;
  late ApiClient client;
  var authErrors = 0;

  setUp(() {
    adapter = FakeAdapter();
    storage = MockSecureStorage();
    authErrors = 0;
    when(() => storage.getAccessToken()).thenAnswer((_) async => 'tok');
    when(() => storage.getRefreshToken()).thenAnswer((_) async => null);
    when(() => storage.clearAll()).thenAnswer((_) async {});
    client = fakeApiClient(adapter, storage: storage)
      ..onAuthError = () => authErrors++;
  });

  test('attaches the bearer token to protected routes', () async {
    adapter.on('GET /feed', {'ok': true});

    await client.dio.get('/feed');

    expect(adapter.last.headers['Authorization'], 'Bearer tok');
  });

  test('does not attach a token to public auth routes', () async {
    adapter.on('POST /auth/login', {'ok': true});

    await client.dio.post('/auth/login');

    expect(adapter.last.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.getAccessToken());
  });

  test('sends no header when there is no stored token', () async {
    when(() => storage.getAccessToken()).thenAnswer((_) async => null);
    adapter.on('GET /feed', {'ok': true});

    await client.dio.get('/feed');

    expect(adapter.last.headers.containsKey('Authorization'), isFalse);
  });

  test('non-401 errors pass through untouched', () async {
    adapter.onError('GET /feed', 500);

    await expectLater(
      client.dio.get('/feed'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          500,
        ),
      ),
    );
    expect(authErrors, 0);
    verifyNever(() => storage.clearAll());
  });

  test('401 on a public route is not refreshed', () async {
    adapter.onError('POST /auth/login', 401);

    await expectLater(
      client.dio.post('/auth/login'),
      throwsA(isA<DioException>()),
    );
    expect(authErrors, 0);
    verifyNever(() => storage.getRefreshToken());
  });

  test('401 without a refresh token clears the session and notifies', () async {
    adapter.onError('GET /feed', 401);

    await expectLater(client.dio.get('/feed'), throwsA(isA<DioException>()));

    verify(() => storage.clearAll()).called(1);
    expect(authErrors, 1);
  });

  test('401 with a failing refresh also forces logout', () async {
    when(
      () => storage.getRefreshToken(),
    ).thenAnswer((_) async => 'old-refresh');
    adapter.onError('GET /feed', 401);

    // The refresh call uses its own Dio (no adapter here), so it fails fast
    // against an unreachable host; the interceptor must log the user out.
    await expectLater(client.dio.get('/feed'), throwsA(isA<DioException>()));

    verify(() => storage.clearAll()).called(1);
    expect(authErrors, 1);
  });
}
