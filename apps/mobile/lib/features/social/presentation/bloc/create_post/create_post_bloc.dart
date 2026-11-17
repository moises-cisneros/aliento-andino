import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/network/network_error.dart';
import '../../../data/repositories/social_repository.dart';
import 'create_post_event.dart';
import 'create_post_state.dart';

class CreatePostBloc extends Bloc<CreatePostEvent, CreatePostState> {
  final SocialRepository _socialRepository;

  CreatePostBloc({required SocialRepository socialRepository})
    : _socialRepository = socialRepository,
      super(const CreatePostInitial()) {
    on<CreatePostSubmit>(_onSubmit);
  }

  Future<void> _onSubmit(
    CreatePostSubmit event,
    Emitter<CreatePostState> emit,
  ) async {
    emit(const CreatePostSubmitting());
    try {
      final post = await _socialRepository.createPost(
        content: event.content,
        postType: event.postType,
        mediaUrl: event.mediaUrl,
        practiceSessionId: event.practiceSessionId,
      );
      emit(CreatePostSuccess(post));
    } catch (e) {
      emit(
        CreatePostError(
          isConnectionError(e)
              ? 'Necesitás conexión a internet para publicar.'
              : e.toString(),
        ),
      );
    }
  }
}
