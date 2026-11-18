import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mobile/features/social/data/models/post_model.dart';
import 'package:mobile/features/social/data/models/user_summary_model.dart';
import 'package:mobile/features/social/data/repositories/social_repository.dart';
import 'package:mobile/features/social/presentation/bloc/social_feed_bloc.dart';
import 'package:mobile/features/social/presentation/bloc/social_feed_event.dart';
import 'package:mobile/features/social/presentation/widgets/applause_button.dart';
import 'package:mobile/features/social/presentation/widgets/social_audio_preview.dart';
import 'package:mobile/features/social/presentation/widgets/social_feed_list.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

PostModel _post(String id) => PostModel(
  id: id,
  user: const UserSummaryModel(id: 'u1', username: 'ana', fullName: 'Ana'),
  content: 'post $id',
  postType: 'text',
  likesCount: 0,
  commentsCount: 0,
  isLikedByMe: false,
  createdAt: '2026-06-20T10:00:00Z',
);

class _FailingPlayer implements PostAudioPlayer {
  @override
  Future<void> play(String url) async => throw Exception('404 audio');
  @override
  Future<void> stop() async {}
  @override
  Stream<bool> get playing => const Stream.empty();
  @override
  void dispose() {}
}

Widget _list(SocialFeedBloc bloc) => MaterialApp(
  home: Scaffold(
    body: BlocProvider.value(
      value: bloc,
      child: SocialFeedList(
        itemBuilder: (ctx, post, i) =>
            SizedBox(height: 120, child: Text(post.content)),
      ),
    ),
  ),
);

void main() {
  testWidgets('ApplauseButton ocupa al menos 48x48 y dispara onPressed', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ApplauseButton(
              isApplauded: false,
              count: 0,
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(ApplauseButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(find.byType(ApplauseButton));
    expect(taps, 1);
  });

  testWidgets('fallo del audio preview muestra icono no disponible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Text('contenido del post'),
              SocialAudioPreview(
                url: 'https://x/a.mp3',
                playerFactory: _FailingPlayer.new,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.volume_off), findsOneWidget);
    expect(find.text('Audio no disponible'), findsOneWidget);
    expect(find.text('contenido del post'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scroll infinito carga la siguiente pagina', (tester) async {
    final repo = MockSocialRepository();
    final page1 = List.generate(12, (i) => _post('a$i'));
    when(() => repo.getFeed()).thenAnswer(
      (_) async => {'items': page1, 'next_cursor': 'c2', 'has_more': true},
    );
    when(() => repo.getFeed(cursor: 'c2')).thenAnswer(
      (_) async => {
        'items': [_post('b0')],
        'next_cursor': null,
        'has_more': false,
      },
    );
    final bloc = SocialFeedBloc(socialRepository: repo)..add(const FeedLoad());
    addTearDown(bloc.close);

    await tester.pumpWidget(_list(bloc));
    await tester.pumpAndSettle();
    verifyNever(() => repo.getFeed(cursor: 'c2'));

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    verify(() => repo.getFeed(cursor: 'c2')).called(1);
    expect(find.text('post b0', skipOffstage: false), findsOneWidget);
  });

  testWidgets('pull-to-refresh recarga la primera pagina', (tester) async {
    final repo = MockSocialRepository();
    when(() => repo.getFeed()).thenAnswer(
      (_) async => {
        'items': [_post('a')],
        'next_cursor': null,
        'has_more': false,
      },
    );
    final bloc = SocialFeedBloc(socialRepository: repo)..add(const FeedLoad());
    addTearDown(bloc.close);
    await tester.pumpWidget(_list(bloc));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    verify(() => repo.getFeed()).called(2);
  });
}
