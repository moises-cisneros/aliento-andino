import '../../../data/models/lesson_model.dart';

/// Resultado del cálculo de la ruta de aprendizaje: qué lecciones están
/// bloqueadas y cuál es la "próxima" a hacer.
class LearningPath {
  final Set<String> lockedIds;
  final LessonModel? next;

  const LearningPath({required this.lockedIds, this.next});

  /// Puntaje mínimo para considerar una lección "dominada" y desbloquear la
  /// siguiente del track. Igual que las apps profesionales (≈70%).
  static const double masteryThreshold = 70.0;

  static int difficultyRank(String d) {
    switch (d) {
      case 'principiante':
        return 0;
      case 'intermedio':
        return 1;
      case 'avanzado':
        return 2;
      case 'experto':
        return 3;
      default:
        return 4;
    }
  }

  static bool isMastered(LessonModel l) =>
      (l.userBestScore ?? 0) >= masteryThreshold;

  static int _compare(LessonModel a, LessonModel b) {
    final r = difficultyRank(a.difficulty).compareTo(difficultyRank(b.difficulty));
    return r != 0 ? r : a.order.compareTo(b.order);
  }

  /// Calcula la ruta por **track de categoría**: dentro de cada categoría las
  /// lecciones se ordenan por dificultad + orden, y se desbloquean de a una al
  /// dominar (≥70%) la anterior. La primera de cada track siempre está
  /// disponible. La "próxima" global es la lección actual de menor dificultad.
  static LearningPath compute(List<LessonModel> all) {
    final locked = <String>{};
    final currents = <LessonModel>[];

    final byCategory = <String, List<LessonModel>>{};
    for (final l in all) {
      byCategory.putIfAbsent(l.categoryId, () => []).add(l);
    }

    for (final track in byCategory.values) {
      track.sort(_compare);
      var reachedCurrent = false;
      for (final lesson in track) {
        if (reachedCurrent) {
          locked.add(lesson.id); // todo lo posterior a la actual queda bloqueado
        } else if (!isMastered(lesson)) {
          currents.add(lesson); // primera no dominada del track = actual
          reachedCurrent = true;
        }
        // dominada → sigue desbloqueada, avanzamos
      }
    }

    currents.sort(_compare);
    return LearningPath(
      lockedIds: locked,
      next: currents.isEmpty ? null : currents.first,
    );
  }
}
