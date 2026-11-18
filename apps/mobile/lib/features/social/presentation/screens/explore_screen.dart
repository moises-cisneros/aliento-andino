import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/social_repository.dart';
import '../widgets/social_post_card.dart';

/// Pantalla Explore: posts populares de las últimas 48h.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final List<PostModel> _posts = [];
  bool _isLoading = true;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<SocialRepository>();
      final result = await repo.getExplore(page: _page);
      setState(() {
        _posts.addAll(result['items'] as List<PostModel>);
        _totalPages = result['pages'] as int;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    final wasLiked = post.isLikedByMe;
    // Optimistic update
    setState(() {
      _posts[index] = post.copyWith(
        isLikedByMe: !wasLiked,
        likesCount: wasLiked ? post.likesCount - 1 : post.likesCount + 1,
      );
    });
    try {
      final repo = context.read<SocialRepository>();
      await repo.toggleLike(post.id);
    } catch (_) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _posts[index] = post;
        });
      }
    }
  }

  Future<void> _toggleSave(int index) async {
    final post = _posts[index];
    setState(() {
      _posts[index] = post.copyWith(isSavedByMe: !post.isSavedByMe);
    });
    try {
      await context.read<SocialRepository>().toggleSave(post.id);
    } catch (_) {
      if (mounted) setState(() => _posts[index] = post);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Explorar')),
      body: _isLoading && _posts.isEmpty
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (scroll) {
                if (scroll.metrics.pixels >=
                        scroll.metrics.maxScrollExtent - 200 &&
                    !_isLoading &&
                    _page < _totalPages) {
                  _page++;
                  _loadPosts();
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return SocialPostCard(
                    post: post,
                    onTap: () => context.push('/social/post/${post.id}'),
                    onLike: () => _toggleLike(index),
                    onComment: () => context.push('/social/post/${post.id}'),
                    onUserTap: () =>
                        context.push('/social/user/${post.user.id}'),
                    onSave: () => _toggleSave(index),
                  );
                },
              ),
            ),
    );
  }
}
