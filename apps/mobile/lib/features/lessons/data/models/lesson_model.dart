/// Modelo de lección/ejercicio de piano.
class LessonModel {
  final String id;
  final String categoryId;
  final String title;
  final String description;
  final String instrument;
  final String difficulty;
  final int tempoBpm;
  final String timeSignature;
  final String keySignature;
  final String? genre;
  final String? artist;
  final String? thumbnailUrl;
  final String? audioPreviewUrl;
  final int? durationSeconds;
  final int order;
  final bool isActive;
  final bool isPremium;
  final int totalPlays;
  final double averageScore;
  final String? createdBy;
  final String? createdAt;
  final String? updatedAt;
  final String? categoryName;
  final int notesCount;
  final double? userBestScore;
  final int userAttempts;
  final bool requiresPremium;

  const LessonModel({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    this.instrument = 'quena',
    required this.difficulty,
    required this.tempoBpm,
    this.timeSignature = '4/4',
    this.keySignature = 'C',
    this.genre,
    this.artist,
    this.thumbnailUrl,
    this.audioPreviewUrl,
    this.durationSeconds,
    this.order = 0,
    this.isActive = true,
    this.isPremium = false,
    this.totalPlays = 0,
    this.averageScore = 0.0,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.categoryName,
    this.notesCount = 0,
    this.userBestScore,
    this.userAttempts = 0,
    this.requiresPremium = false,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id: (json['id'] as String?) ?? '',
      categoryId: (json['category_id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      instrument: (json['instrument'] as String?) ?? 'quena',
      difficulty: (json['difficulty'] as String?) ?? 'principiante',
      tempoBpm: json['tempo_bpm'] as int? ?? 60,
      timeSignature: json['time_signature'] as String? ?? '4/4',
      keySignature: json['key_signature'] as String? ?? 'C',
      genre: json['genre'] as String?,
      artist: json['artist'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      audioPreviewUrl: json['audio_preview_url'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      order: json['order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      isPremium: json['is_premium'] as bool? ?? false,
      totalPlays: json['total_plays'] as int? ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      categoryName: json['category_name'] as String?,
      notesCount: json['notes_count'] as int? ?? 0,
      userBestScore: (json['user_best_score'] as num?)?.toDouble(),
      userAttempts: json['user_attempts'] as int? ?? 0,
      requiresPremium: json['requires_premium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category_id': categoryId,
    'title': title,
    'description': description,
    'instrument': instrument,
    'difficulty': difficulty,
    'tempo_bpm': tempoBpm,
    'time_signature': timeSignature,
    'key_signature': keySignature,
    'genre': genre,
    'artist': artist,
    'thumbnail_url': thumbnailUrl,
    'audio_preview_url': audioPreviewUrl,
    'duration_seconds': durationSeconds,
    'order': order,
    'is_active': isActive,
    'is_premium': isPremium,
    'total_plays': totalPlays,
    'average_score': averageScore,
  };
}
