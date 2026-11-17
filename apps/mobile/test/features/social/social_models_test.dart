import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/social/data/models/comment_model.dart';
import 'package:mobile/features/social/data/models/post_model.dart';

void main() {
  group('PostModel', () {
    test('fromJson parsea is_saved_by_me e is_liked_by_me', () {
      final post = PostModel.fromJson({
        'id': 'p1',
        'user': {'id': 'u1', 'username': 'ana', 'full_name': 'Ana López'},
        'content': 'Practicando #jazz con @luis',
        'post_type': 'text',
        'likes_count': 3,
        'comments_count': 1,
        'is_liked_by_me': true,
        'is_saved_by_me': true,
        'created_at': '2026-06-20T10:00:00Z',
      });

      expect(post.id, 'p1');
      expect(post.isLikedByMe, isTrue);
      expect(post.isSavedByMe, isTrue);
      expect(post.likesCount, 3);
      expect(post.user.username, 'ana');
    });

    test('is_saved_by_me ausente => false por defecto', () {
      final post = PostModel.fromJson({
        'id': 'p2',
        'user': {'id': 'u1', 'username': 'ana', 'full_name': 'Ana'},
        'content': 'hola',
        'post_type': 'text',
        'likes_count': 0,
        'comments_count': 0,
        'is_liked_by_me': false,
        'created_at': '2026-06-20T10:00:00Z',
      });

      expect(post.isSavedByMe, isFalse);
    });

    test('copyWith preserva campos y actualiza solo lo indicado', () {
      final post = PostModel.fromJson({
        'id': 'p3',
        'user': {'id': 'u1', 'username': 'ana', 'full_name': 'Ana'},
        'content': 'original',
        'post_type': 'text',
        'likes_count': 5,
        'comments_count': 0,
        'is_liked_by_me': false,
        'is_saved_by_me': false,
        'created_at': '2026-06-20T10:00:00Z',
      });

      final edited = post.copyWith(content: 'editado', isSavedByMe: true);

      expect(edited.content, 'editado');
      expect(edited.isSavedByMe, isTrue);
      // No tocados:
      expect(edited.id, 'p3');
      expect(edited.likesCount, 5);
      expect(edited.isLikedByMe, isFalse);
    });
  });

  group('CommentModel', () {
    test('fromJson parsea likes_count e is_liked_by_me (Fase 3)', () {
      final comment = CommentModel.fromJson({
        'id': 'c1',
        'post_id': 'p1',
        'replies_count': 2,
        'likes_count': 4,
        'is_liked_by_me': true,
        'user': {'id': 'u1', 'username': 'ana', 'full_name': 'Ana'},
        'content': 'buen comentario',
        'created_at': '2026-06-20T10:00:00Z',
      });

      expect(comment.likesCount, 4);
      expect(comment.isLikedByMe, isTrue);
      expect(comment.repliesCount, 2);
    });

    test('copyWith del like optimista mantiene el resto', () {
      final comment = CommentModel.fromJson({
        'id': 'c2',
        'post_id': 'p1',
        'likes_count': 0,
        'is_liked_by_me': false,
        'user': {'id': 'u1', 'username': 'ana', 'full_name': 'Ana'},
        'content': 'hola',
        'created_at': '2026-06-20T10:00:00Z',
      });

      final liked = comment.copyWith(isLikedByMe: true, likesCount: 1);

      expect(liked.isLikedByMe, isTrue);
      expect(liked.likesCount, 1);
      expect(liked.content, 'hola');
      expect(liked.id, 'c2');
    });
  });
}
