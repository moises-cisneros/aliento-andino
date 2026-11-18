import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/post_model.dart';
import '../bloc/social_feed_bloc.dart';
import '../bloc/social_feed_event.dart';
import '../bloc/social_feed_state.dart';

/// Lista del feed con pull-to-refresh y scroll infinito sobre [SocialFeedBloc].
class SocialFeedList extends StatelessWidget {
  final Widget Function(BuildContext context, PostModel post, int index)
  itemBuilder;

  const SocialFeedList({super.key, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SocialFeedBloc, FeedState>(
      builder: (context, state) {
        if (state is! FeedLoaded) return const SizedBox.shrink();
        final bloc = context.read<SocialFeedBloc>();
        return RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () async {
            bloc.add(const FeedRefresh());
            // Mantiene el spinner hasta que el bloc termine de recargar.
            await bloc.stream.firstWhere(
              (s) => s is FeedLoaded || s is FeedError,
            );
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (scroll) {
              if (scroll.metrics.pixels >=
                  scroll.metrics.maxScrollExtent - 200) {
                bloc.add(const FeedLoadMore());
              }
              return false;
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
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
                return itemBuilder(context, state.posts[index], index);
              },
            ),
          ),
        );
      },
    );
  }
}
