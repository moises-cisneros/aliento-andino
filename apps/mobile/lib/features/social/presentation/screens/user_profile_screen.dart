import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/user_repository.dart';
import '../bloc/user_profile/user_profile_bloc.dart';
import '../bloc/user_profile/user_profile_event.dart';
import '../bloc/user_profile/user_profile_state.dart';
import '../widgets/follow_button.dart';
import '../widgets/post_card.dart';
import '../widgets/user_avatar.dart';

/// Pantalla de perfil de usuario con pestañas Publicaciones / Media.
class UserProfileScreen extends StatelessWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          UserProfileBloc(userRepository: ctx.read<UserRepository>())
            ..add(UserProfileLoad(userId)),
      child: _UserProfileView(userId: userId),
    );
  }
}

class _UserProfileView extends StatefulWidget {
  final String userId;
  const _UserProfileView({required this.userId});

  @override
  State<_UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<_UserProfileView> {
  int _tab = 0; // 0 = Publicaciones, 1 = Media

  final List<PostModel> _media = [];
  bool _mediaLoading = false;
  bool _mediaLoaded = false;
  String? _mediaCursor;
  bool _mediaHasMore = true;

  Future<void> _loadMedia() async {
    if (_mediaLoading || !_mediaHasMore) return;
    setState(() => _mediaLoading = true);
    try {
      final result = await context.read<UserRepository>().getUserMedia(
        widget.userId,
        cursor: _mediaCursor,
      );
      if (!mounted) return;
      setState(() {
        _media.addAll(result['items'] as List<PostModel>);
        _mediaCursor = result['next_cursor'] as String?;
        _mediaHasMore = result['has_more'] as bool;
        _mediaLoading = false;
        _mediaLoaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _mediaLoading = false;
          _mediaLoaded = true;
        });
      }
    }
  }

  void _selectTab(int t) {
    if (_tab == t) return;
    setState(() => _tab = t);
    if (t == 1 && !_mediaLoaded) _loadMedia();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Perfil')),
      body: BlocBuilder<UserProfileBloc, UserProfileState>(
        builder: (context, state) {
          if (state is UserProfileLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }
          if (state is UserProfileError) {
            return Center(
              child: Text(
                state.message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          if (state is UserProfileLoaded) {
            final p = state.profile;
            return NotificationListener<ScrollNotification>(
              onNotification: (scroll) {
                if (scroll.metrics.pixels >=
                    scroll.metrics.maxScrollExtent - 200) {
                  if (_tab == 0) {
                    context.read<UserProfileBloc>().add(
                      const UserProfileLoadMorePosts(),
                    );
                  } else if (_mediaHasMore && !_mediaLoading) {
                    _loadMedia();
                  }
                }
                return false;
              },
              child: CustomScrollView(
                slivers: [
                  // Header de perfil
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          UserAvatar(imageUrl: p.avatarUrl, radius: 44),
                          const SizedBox(height: 12),
                          Text(
                            p.fullName,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '@${p.username}',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 14,
                            ),
                          ),
                          if (p.bio != null && p.bio!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                p.bio!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          // Contadores
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _counter(context, '${p.postsCount}', 'Posts'),
                              const SizedBox(width: 32),
                              GestureDetector(
                                onTap: () => context.push(
                                  '/social/user/${widget.userId}/followers',
                                ),
                                child: _counter(
                                  context,
                                  '${p.followersCount}',
                                  'Seguidores',
                                ),
                              ),
                              const SizedBox(width: 32),
                              GestureDetector(
                                onTap: () => context.push(
                                  '/social/user/${widget.userId}/followers',
                                ),
                                child: _counter(
                                  context,
                                  '${p.followingCount}',
                                  'Siguiendo',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FollowButton(
                            isFollowing: p.isFollowedByMe,
                            onPressed: () => context
                                .read<UserProfileBloc>()
                                .add(const UserProfileToggleFollow()),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Selector de pestañas
                  SliverToBoxAdapter(child: _tabSelector(context)),
                  SliverToBoxAdapter(
                    child: Divider(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      height: 1,
                    ),
                  ),
                  // Contenido según pestaña
                  if (_tab == 0)
                    ..._buildPostsSlivers(context, state)
                  else
                    ..._buildMediaSlivers(context),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _tabSelector(BuildContext context) {
    return Row(
      children: [
        _tabButton(context, 0, Icons.grid_view_rounded, 'Publicaciones'),
        _tabButton(context, 1, Icons.photo_library_outlined, 'Media'),
      ],
    );
  }

  Widget _tabButton(
    BuildContext context,
    int index,
    IconData icon,
    String label,
  ) {
    final cs = Theme.of(context).colorScheme;
    final selected = _tab == index;
    return Expanded(
      child: InkWell(
        onTap: () => _selectTab(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? cs.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? cs.primary : Theme.of(context).hintColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? cs.primary : Theme.of(context).hintColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPostsSlivers(
    BuildContext context,
    UserProfileLoaded state,
  ) {
    if (state.posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              'Sin publicaciones aún',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= state.posts.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          }
          final post = state.posts[index];
          return PostCard(
            post: post,
            onTap: () => context.push('/social/post/${post.id}'),
            onLike: () {},
            onComment: () => context.push('/social/post/${post.id}'),
            onUserTap: () {},
          );
        }, childCount: state.posts.length + (state.isLoadingMore ? 1 : 0)),
      ),
    ];
  }

  List<Widget> _buildMediaSlivers(BuildContext context) {
    if (_mediaLoading && _media.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ];
    }
    if (_media.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  color: Theme.of(context).hintColor,
                  size: 48,
                ),
                const SizedBox(height: 10),
                Text(
                  'Sin fotos aún',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.all(2),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final post = _media[index];
            final url = post.mediaThumbnailUrl ?? post.mediaUrl;
            return GestureDetector(
              onTap: () => context.push('/social/post/${post.id}'),
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: url == null
                    ? const SizedBox.shrink()
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) =>
                            const Icon(Icons.broken_image),
                      ),
              ),
            );
          }, childCount: _media.length),
        ),
      ),
      if (_mediaLoading)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
    ];
  }

  Widget _counter(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),
      ],
    );
  }
}
