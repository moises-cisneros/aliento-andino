import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/lessons/data/models/lesson_model.dart';
import 'package:mobile/features/lessons/presentation/bloc/lessons/learning_path.dart';

LessonModel _l(String id, String cat, String diff, int order, {double? best}) =>
    LessonModel(
      id: id,
      categoryId: cat,
      title: id,
      description: '',
      difficulty: diff,
      tempoBpm: 60,
      order: order,
      userBestScore: best,
    );

void main() {
  group('LearningPath.compute', () {
    test('sin progreso: solo la primera de cada track queda desbloqueada', () {
      final p = LearningPath.compute([
        _l('a1', 'cat', 'principiante', 1),
        _l('a2', 'cat', 'principiante', 2),
        _l('a3', 'cat', 'intermedio', 1),
      ]);
      expect(p.lockedIds, {'a2', 'a3'});
      expect(p.next?.id, 'a1');
    });

    test('dominar la primera (>=70%) desbloquea la siguiente', () {
      final p = LearningPath.compute([
        _l('a1', 'cat', 'principiante', 1, best: 85),
        _l('a2', 'cat', 'principiante', 2),
        _l('a3', 'cat', 'intermedio', 1),
      ]);
      expect(p.lockedIds, {'a3'});
      expect(p.next?.id, 'a2');
    });

    test('umbral exacto: 69% no domina, 70% sí', () {
      final below = LearningPath.compute([
        _l('a', 'c', 'principiante', 1, best: 69),
        _l('b', 'c', 'principiante', 2),
      ]);
      expect(below.lockedIds.contains('b'), isTrue);

      final at = LearningPath.compute([
        _l('a', 'c', 'principiante', 1, best: 70),
        _l('b', 'c', 'principiante', 2),
      ]);
      expect(at.lockedIds.contains('b'), isFalse);
    });

    test('los tracks de cada categoría son independientes', () {
      final p = LearningPath.compute([
        _l('a1', 'catA', 'principiante', 1, best: 90),
        _l('a2', 'catA', 'principiante', 2),
        _l('b1', 'catB', 'principiante', 1),
        _l('b2', 'catB', 'principiante', 2),
      ]);
      // catA: a1 dominada -> a2 libre. catB: b1 libre, b2 bloqueada.
      expect(p.lockedIds, {'b2'});
    });

    test('ordena por dificultad dentro del track', () {
      // El experto va último aunque tenga order bajo.
      final p = LearningPath.compute([
        _l('exp', 'c', 'experto', 1),
        _l('beg', 'c', 'principiante', 9),
      ]);
      expect(p.next?.id, 'beg'); // la primera del track es la principiante
      expect(p.lockedIds, {'exp'});
    });

    test('todo dominado: nada bloqueado y sin próxima', () {
      final p = LearningPath.compute([
        _l('a', 'c', 'principiante', 1, best: 100),
        _l('b', 'c', 'principiante', 2, best: 100),
      ]);
      expect(p.lockedIds, isEmpty);
      expect(p.next, isNull);
    });
  });
}
