/// Respuesta de `POST /api/v1/social/posts/{id}/react`.
///
/// Espejo de `ReactionToggleResponse` (Pydantic): `liked` y `likes_count`.
class ReactionToggleModel {
  final bool liked;
  final int likesCount;

  const ReactionToggleModel({required this.liked, required this.likesCount});

  factory ReactionToggleModel.fromJson(Map<String, dynamic> json) {
    return ReactionToggleModel(
      liked: json['liked'] as bool,
      likesCount: json['likes_count'] as int,
    );
  }
}
