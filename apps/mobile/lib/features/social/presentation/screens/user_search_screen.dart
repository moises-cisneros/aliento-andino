import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/post_model.dart';
import '../../data/models/user_summary_model.dart';
import '../../data/repositories/social_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../widgets/post_card.dart';
import '../widgets/user_avatar.dart';

/// Pantalla de búsqueda con tabs: Usuarios | Posts (por contenido o #hashtag).
class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();

  List<UserSummaryModel> _userResults = [];
  List<PostModel> _postResults = [];
  bool _loading = false;
  bool _hasSearched = false;
  String _lastQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_lastQuery.isNotEmpty) _search(_lastQuery);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Búsqueda en vivo: dispara tras ~350ms sin escribir (mín. 2 caracteres).
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _search(q);
    });
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    _lastQuery = q;
    setState(() {
      _loading = true;
      _hasSearched = true;
    });
    try {
      if (_tabController.index == 0) {
        final res = await context.read<UserRepository>().searchUsers(q);
        if (!mounted) return;
        setState(() {
          _userResults = res['items'] as List<UserSummaryModel>;
          _loading = false;
        });
      } else {
        final posts = await context.read<SocialRepository>().searchPosts(q);
        if (!mounted) return;
        setState(() {
          _postResults = posts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: _tabController.index == 0
                ? 'Buscar usuarios...'
                : 'Buscar posts o #hashtags...',
            hintStyle: TextStyle(color: Theme.of(context).hintColor),
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
          onSubmitted: _search,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_searchController.text),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Usuarios'),
            Tab(icon: Icon(Icons.article), text: 'Posts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildUsersTab(), _buildPostsTab()],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_loading && _tabController.index == 0) return _spinner();
    if (!_hasSearched) {
      return _emptyState('Buscá usuarios por nombre', Icons.person_search);
    }
    if (_userResults.isEmpty) {
      return _emptyState('Sin resultados', Icons.search_off);
    }
    return ListView.builder(
      itemCount: _userResults.length,
      itemBuilder: (context, i) {
        final user = _userResults[i];
        return ListTile(
          leading: UserAvatar(user: user, radius: 22),
          title: Text(
            user.fullName,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          subtitle: Text(
            '@${user.username}',
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
          ),
          onTap: () => context.push('/social/user/${user.id}'),
        );
      },
    );
  }

  Widget _buildPostsTab() {
    if (_loading && _tabController.index == 1) return _spinner();
    if (!_hasSearched) {
      return _emptyState('Buscá posts o usá #hashtag', Icons.tag);
    }
    if (_postResults.isEmpty) {
      return _emptyState('Sin resultados', Icons.search_off);
    }
    return ListView.builder(
      itemCount: _postResults.length,
      itemBuilder: (context, i) {
        final post = _postResults[i];
        return PostCard(
          post: post,
          onTap: () => context.push('/social/post/${post.id}'),
          onUserTap: () => context.push('/social/user/${post.user.id}'),
          onLike: () {}, // no-op aquí, la pantalla de detalle maneja likes
          onComment: () => context.push('/social/post/${post.id}'),
        );
      },
    );
  }

  Widget _spinner() => Center(
    child: CircularProgressIndicator(
      color: Theme.of(context).colorScheme.primary,
    ),
  );

  Widget _emptyState(String msg, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            size: 56,
          ),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
        ],
      ),
    );
  }
}
