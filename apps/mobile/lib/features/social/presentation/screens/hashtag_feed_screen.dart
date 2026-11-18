import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/post_model.dart';
import '../../data/repositories/social_repository.dart';
import '../widgets/social_post_card.dart';

/// Feed de posts que contienen un hashtag.
class HashtagFeedScreen extends StatefulWidget {
  final String tag;

  const HashtagFeedScreen({super.key, required this.tag});

  @override
  State<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends State<HashtagFeedScreen> {
  final List<PostModel> _posts = [];
  bool _isLoading = true;
  String? _cursor;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<SocialRepository>();
      final result = await repo.getHashtagFeed(widget.tag, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _posts.addAll(result['items'] as List<PostModel>);
        _cursor = result['next_cursor'] as String?;
        _hasMore = result['has_more'] as bool;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    final wasLiked = post.isLikedByMe;
    setState(() {
      _posts[index] = post.copyWith(
        isLikedByMe: !wasLiked,
        likesCount: wasLiked ? post.likesCount - 1 : post.likesCount + 1,
      );
    });
    try {
      await context.read<SocialRepository>().toggleLike(post.id);
    } catch (_) {
      if (mounted) setState(() => _posts[index] = post);
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text('#${widget.tag}')),
      body: _isLoading && _posts.isEmpty
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _posts.isEmpty
          ? Center(
              child: Text(
                'Sin publicaciones con #${widget.tag}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (scroll) {
                if (scroll.metrics.pixels >=
                        scroll.metrics.maxScrollExtent - 200 &&
                    !_isLoading &&
                    _hasMore) {
                  _load();
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
