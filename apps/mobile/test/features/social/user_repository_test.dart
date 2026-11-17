import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/social/data/repositories/user_repository.dart';

import '../../helpers/fake_api.dart';

Map<String, dynamic> _profile() => {
  'id': 'u1',
  'username': 'ana',
  'full_name': 'Ana Quena',
  'bio': 'Quenista',
  'followers_count': 4,
  'following_count': 2,
  'posts_count': 7,
  'is_followed_by_me': true,
  'created_at': '2026-01-01T00:00:00Z',
};

void main() {
  late FakeAdapter adapter;
  late UserRepository repo;

  setUp(() {
    adapter = FakeAdapter();
    repo = UserRepository(apiClient: fakeApiClient(adapter));
  });

  test('getUserProfile maps the public profile', () async {
    adapter.on('GET /users/u1/profile', _profile());

    final profile = await repo.getUserProfile('u1');

    expect(profile.username, 'ana');
    expect(profile.followersCount, 4);
    expect(profile.isFollowedByMe, isTrue);
  });

  test('getUserIdByUsername resolves the id', () async {
    adapter.on('GET /users/by-username/ana', {'id': 'u1'});

    expect(await repo.getUserIdByUsername('ana'), 'u1');
  });

  test('getUserPosts and getUserMedia send the cursor when present', () async {
    adapter
      ..on('GET /users/u1/posts', pageJson([postJson()]))
      ..on('GET /users/u1/media', pageJson([postJson(), postJson()]));

    final posts = await repo.getUserPosts('u1', cursor: 'c', limit: 5);
    expect(adapter.last.queryParameters, {'limit': 5, 'cursor': 'c'});
    expect((posts['items'] as List).length, 1);
    expect(posts['has_more'], isTrue);

    final media = await repo.getUserMedia('u1');
    expect(adapter.last.queryParameters, {'limit': 20});
    expect((media['items'] as List).length, 2);
  });

  test('toggleFollow returns the server payload', () async {
    adapter.on('POST /users/u1/follow', {'following': true});

    expect((await repo.toggleFollow('u1'))['following'], isTrue);
  });

  test('getSuggestions parses a plain list', () async {
    adapter.on('GET /users/suggestions', [userJson(), userJson(id: 'u2')]);

    final users = await repo.getSuggestions(limit: 2);

    expect(users.map((u) => u.id), ['u1', 'u2']);
    expect(adapter.last.queryParameters, {'limit': 2});
  });

  test('followers, following and search return paginated users', () async {
    adapter
      ..on('GET /users/u1/followers', pageJson([userJson()]))
      ..on('GET /users/u1/following', pageJson([userJson(), userJson()]))
      ..on('GET /users/search', pageJson([userJson()]));

    final followers = await repo.getFollowers('u1');
    final following = await repo.getFollowing('u1', page: 2);
    final search = await repo.searchUsers('ana');

    expect((followers['items'] as List).length, 1);
    expect((following['items'] as List).length, 2);
    expect(following['total'], 2);
    expect(adapter.requests[1].queryParameters['page'], 2);
    expect(search['pages'], 1);
    expect(adapter.last.queryParameters['q'], 'ana');
  });
}
