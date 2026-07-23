import 'package:equatable/equatable.dart';
import '../../../data/models/post_model.dart';

abstract class CreatePostState extends Equatable {
  const CreatePostState();

  @override
  List<Object?> get props => [];
}

class CreatePostInitial extends CreatePostState {
  const CreatePostInitial();
}

class CreatePostSubmitting extends CreatePostState {
  const CreatePostSubmitting();
}

class CreatePostSuccess extends CreatePostState {
  final PostModel post;
  const CreatePostSuccess(this.post);

  @override
  List<Object?> get props => [post];
}

class CreatePostError extends CreatePostState {
  final String message;
  const CreatePostError(this.message);

  @override
  List<Object?> get props => [message];
}
