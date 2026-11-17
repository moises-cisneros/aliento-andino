import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mobile/features/social/data/models/post_model.dart';
import 'package:mobile/features/social/data/models/user_summary_model.dart';
import 'package:mobile/features/social/data/repositories/social_repository.dart';
import 'package:mobile/features/social/presentation/bloc/feed/feed_bloc.dart';
import 'package:mobile/features/social/presentation/bloc/feed/feed_event.dart';
import 'package:mobile/features/social/presentation/bloc/feed/feed_state.dart';

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

Map<String, dynamic> _page(List<PostModel> items) => {
  'items': items,
  'next_cursor': null,
  'has_more': false,
};

void main() {
  late MockSocialRepository repo;

  setUp(() => repo = MockSocialRepository());

  group('FeedBloc', () {
    blocTest<FeedBloc, FeedState>(
      'FeedLoad carga el feed de seguidos (modo following)',
      setUp: () {
        when(() => repo.getFeed()).thenAnswer((_) async => _page([_post('1')]));
      },
      build: () => FeedBloc(socialRepository: repo),
      act: (bloc) => bloc.add(const FeedLoad()),
      expect: () => [
        isA<FeedLoading>(),
        isA<FeedLoaded>()
            .having((s) => s.mode, 'mode', FeedMode.following)
            .having((s) => s.posts.length, 'posts', 1),
      ],
      verify: (_) => verify(() => repo.getFeed()).called(1),
    );

    blocTest<FeedBloc, FeedState>(
      'FeedSwitchMode(recent) usa getRecentFeed (Fase 4)',
      setUp: () {
        when(() => repo.getFeed()).thenAnswer((_) async => _page([_post('1')]));
        when(
          () => repo.getRecentFeed(),
        ).thenAnswer((_) async => _page([_post('9'), _post('10')]));
      },
      build: () => FeedBloc(socialRepository: repo),
      act: (bloc) async {
        bloc.add(const FeedLoad());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FeedSwitchMode(FeedMode.recent));
      },
      skip: 2, // saltar el load inicial (Loading + Loaded following)
      expect: () => [
        isA<FeedLoading>().having((s) => s.mode, 'mode', FeedMode.recent),
        isA<FeedLoaded>()
            .having((s) => s.mode, 'mode', FeedMode.recent)
            .having((s) => s.posts.length, 'posts', 2),
      ],
      verify: (_) => verify(() => repo.getRecentFeed()).called(1),
    );

    blocTest<FeedBloc, FeedState>(
      'FeedToggleSave invierte isSavedByMe de forma optimista',
      setUp: () {
        when(() => repo.getFeed()).thenAnswer((_) async => _page([_post('1')]));
        when(() => repo.toggleSave('1')).thenAnswer((_) async => true);
      },
      build: () => FeedBloc(socialRepository: repo),
      act: (bloc) async {
        bloc.add(const FeedLoad());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FeedToggleSave('1'));
      },
      skip: 2,
      expect: () => [
        isA<FeedLoaded>().having(
          (s) => s.posts.first.isSavedByMe,
          'isSavedByMe',
          true,
        ),
      ],
      verify: (_) => verify(() => repo.toggleSave('1')).called(1),
    );
  });
}
