import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/connectivity/connectivity_service.dart';
import 'package:mobile/features/tutor/data/tutor_repository.dart';
import 'package:mobile/features/tutor/offline/offline_faq_assistant.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_api.dart';

class _MockConnectivity extends Mock implements ConnectivityService {}

class _MockFaq extends Mock implements OfflineFaqAssistant {}

const _cloudReply = {
  'reply': 'Respuesta de la nube',
  'actions': [
    {
      'tool': 'navigate',
      'args': {'route': '/lessons'},
    },
  ],
};

void main() {
  late FakeAdapter adapter;
  late _MockConnectivity connectivity;
  late _MockFaq faq;
  late TutorRepository repo;

  setUp(() {
    adapter = FakeAdapter();
    connectivity = _MockConnectivity();
    faq = _MockFaq();
    when(() => connectivity.isOnline).thenAnswer((_) async => true);
    repo = TutorRepository(
      apiClient: fakeApiClient(adapter),
      connectivity: connectivity,
      offlineAssistant: faq,
    );
  });

  FaqMatch match(double score, {TutorAction? action}) =>
      FaqMatch('faq', 'Respuesta local', action, score);

  group('models', () {
    test('TutorMessage serializes to role and text', () {
      expect(const TutorMessage(role: 'user', text: 'hola').toJson(), {
        'role': 'user',
        'text': 'hola',
      });
    });

    test('TutorReply and TutorAction tolerate missing fields', () {
      final reply = TutorReply.fromJson(<String, dynamic>{});
      expect(reply.reply, '');
      expect(reply.actions, isEmpty);

      final action = TutorAction.fromJson(<String, dynamic>{});
      expect(action.tool, '');
      expect(action.args, isEmpty);
    });
  });

  group('online', () {
    test(
      'uses the cloud agent and sends history, route and long timeouts',
      () async {
        adapter.on('POST /tutor/chat', _cloudReply);
        final history = List.generate(
          12,
          (i) => TutorMessage(role: 'user', text: 'm$i'),
        );

        final reply = await repo.chat('hola', history, currentRoute: '/home');

        expect(reply.reply, 'Respuesta de la nube');
        expect(reply.actions.single.tool, 'navigate');
        final body = adapter.last.data as Map<String, dynamic>;
        expect(body['message'], 'hola');
        expect(body['current_route'], '/home');
        expect((body['history'] as List).length, 10);
        expect(adapter.last.receiveTimeout, const Duration(seconds: 60));
      },
    );

    test('omits current_route when not provided', () async {
      adapter.on('POST /tutor/chat', _cloudReply);

      await repo.chat('hola', const []);

      expect((adapter.last.data as Map).containsKey('current_route'), isFalse);
    });

    test('a cloud failure falls back to a confident FAQ answer', () async {
      adapter.onError('POST /tutor/chat', 500);
      const action = TutorAction(tool: 'navigate', args: {'route': '/x'});
      when(() => faq.bestMatch(any())).thenAnswer(
        (_) async => match(OfflineFaqAssistant.matchThreshold, action: action),
      );

      final reply = await repo.chat('hola', const []);

      expect(reply.reply, 'Respuesta local');
      expect(reply.actions.single, action);
    });

    test('a cloud failure with a weak FAQ match rethrows', () async {
      adapter.onError('POST /tutor/chat', 500);
      when(() => faq.bestMatch(any())).thenAnswer((_) async => match(0.01));

      await expectLater(
        repo.chat('hola', const []),
        throwsA(isA<DioException>()),
      );
    });

    test('without connectivity info it assumes online', () async {
      adapter.on('POST /tutor/chat', _cloudReply);
      final noConn = TutorRepository(apiClient: fakeApiClient(adapter));

      expect(
        (await noConn.chat('hola', const [])).reply,
        'Respuesta de la nube',
      );
    });

    test('a connectivity error is treated as online', () async {
      when(() => connectivity.isOnline).thenThrow(StateError('boom'));
      adapter.on('POST /tutor/chat', _cloudReply);

      expect((await repo.chat('hola', const [])).reply, 'Respuesta de la nube');
    });
  });

  group('offline', () {
    setUp(
      () => when(() => connectivity.isOnline).thenAnswer((_) async => false),
    );

    test('answers from the FAQ when the match is confident', () async {
      when(() => faq.bestMatch(any())).thenAnswer((_) async => match(0.9));

      final reply = await repo.chat('como descargo', const []);

      expect(reply.reply, 'Respuesta local');
      expect(reply.actions, isEmpty);
      expect(adapter.requests, isEmpty);
    });

    test('shows the offline notice when nothing matches', () async {
      when(() => faq.bestMatch(any())).thenAnswer((_) async => match(0.0));

      final reply = await repo.chat('algo raro', const []);

      expect(reply.reply, contains('sin conexión'));
      expect(reply.actions, isEmpty);
    });

    test('shows the offline notice without an assistant', () async {
      final bare = TutorRepository(
        apiClient: fakeApiClient(adapter),
        connectivity: connectivity,
      );

      expect(
        (await bare.chat('hola', const [])).reply,
        contains('sin conexión'),
      );
    });
  });

  test('the conversation is kept until cleared', () {
    repo.conversation.add(const TutorMessage(role: 'user', text: 'hola'));
    expect(repo.conversation, hasLength(1));

    repo.clearConversation();

    expect(repo.conversation, isEmpty);
  });
}
