import 'package:equatable/equatable.dart';

abstract class CreatePostEvent extends Equatable {
  const CreatePostEvent();

  @override
  List<Object?> get props => [];
}

class CreatePostSubmit extends CreatePostEvent {
  final String content;
  final String postType;
  final String? mediaUrl;
  final String? practiceSessionId;

  const CreatePostSubmit({
    required this.content,
    this.postType = 'text',
    this.mediaUrl,
    this.practiceSessionId,
  });

  @override
  List<Object?> get props => [content, postType, mediaUrl, practiceSessionId];
}
