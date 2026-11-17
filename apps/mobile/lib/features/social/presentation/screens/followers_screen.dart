import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/models/user_summary_model.dart';
import '../../data/repositories/user_repository.dart';
import '../widgets/follow_button.dart';
import '../widgets/user_avatar.dart';

/// Pantalla de lista de seguidores / siguiendo.
class FollowersScreen extends StatefulWidget {
  final String userId;
  final bool showFollowers; // true = seguidores, false = siguiendo

  const FollowersScreen({
    super.key,
    required this.userId,
    this.showFollowers = true,
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<UserSummaryModel> _followers = [];
  final List<UserSummaryModel> _following = [];
  bool _isLoadingFollowers = true;
  bool _isLoadingFollowing = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showFollowers ? 0 : 1,
    );
    _loadFollowers();
    _loadFollowing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowers() async {
    try {
      final repo = context.read<UserRepository>();
      final result = await repo.getFollowers(widget.userId);
      setState(() {
        _followers.addAll(result['items'] as List<UserSummaryModel>);
        _isLoadingFollowers = false;
      });
    } catch (_) {
      setState(() => _isLoadingFollowers = false);
    }
  }

  Future<void> _loadFollowing() async {
    try {
      final repo = context.read<UserRepository>();
      final result = await repo.getFollowing(widget.userId);
      setState(() {
        _following.addAll(result['items'] as List<UserSummaryModel>);
        _isLoadingFollowing = false;
      });
    } catch (_) {
      setState(() => _isLoadingFollowing = false);
    }
  }

  String? get _myId {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated ? s.user.id : null;
  }

  Future<void> _toggleFollow(List<UserSummaryModel> list, int index) async {
    final user = list[index];
    final wasFollowing = user.isFollowedByMe ?? false;
    setState(() => list[index] = user.copyWith(isFollowedByMe: !wasFollowing));
    try {
      await context.read<UserRepository>().toggleFollow(user.id);
    } catch (_) {
      if (mounted) setState(() => list[index] = user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Conexiones'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).hintColor,
          tabs: const [
            Tab(text: 'Seguidores'),
            Tab(text: 'Siguiendo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(_followers, _isLoadingFollowers),
          _buildUserList(_following, _isLoadingFollowing),
        ],
      ),
    );
  }

  Widget _buildUserList(List<UserSummaryModel> users, bool isLoading) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    if (users.isEmpty) {
      return Center(
        child: Text(
          'Sin usuarios',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 16),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isSelf = user.id == _myId;
        // Fila propia (Row) en vez de ListTile: con el botón de seguir como
        // trailing, el ListTile puede aseverar "trailing excede el ancho" en
        // pantallas angostas. El Expanded del nombre garantiza el reparto.
        return InkWell(
          onTap: () => context.push('/social/user/${user.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                UserAvatar(user: user, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '@${user.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isSelf) ...[
                  const SizedBox(width: 8),
                  FollowButton(
                    isFollowing: user.isFollowedByMe ?? false,
                    onPressed: () => _toggleFollow(users, index),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
