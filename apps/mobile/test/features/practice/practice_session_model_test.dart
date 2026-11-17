import 'dart:convert';

import 'package:mobile/features/practice/data/models/practice_session_model.dart';
import 'package:flutter_test/flutter_test.dart';

PracticeSessionModel _sample({String clientId = 'c1'}) => PracticeSessionModel(
  lessonId: 'lesson-1',
  clientId: clientId,
  score: 87.123456789,
  correctNotes: 17,
  totalNotes: 20,
  wrongNotes: 2,
  missedNotes: 1,
  averageTempo: 71.3333333,
  totalTimeSeconds: 123.456,
  errorsDetail: const [
    {'position': 3, 'note': 'A4', 'cents': -22.5},
  ],
);

void main() {
  group('toJson', () {
    test('contains every contract field', () {
      final json = _sample().toJson();
      for (final key in const [
        'lesson_id',
        'client_id',
        'score',
        'correct_notes',
        'total_notes',
        'wrong_notes',
        'missed_notes',
        'average_tempo',
        'total_time_seconds',
        'errors_detail',
      ]) {
        expect(json.containsKey(key), isTrue, reason: 'missing $key');
      }
      expect(json['client_id'], 'c1');
      expect(json['lesson_id'], 'lesson-1');
    });

    test('round trip through JSON text loses no precision', () {
      final original = _sample();
      final decoded = PracticeSessionModel.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, original);
      expect(decoded.score, 87.123456789);
      expect(decoded.averageTempo, 71.3333333);
      expect(decoded.errorsDetail, original.errorsDetail);
    });

    test('payload with 100 detailed errors stays under 5 KB', () {
      final errors = List.generate(
        100,
        (i) => {'position': i, 'note': 'A4', 'cents': -12.5},
      );
      final model = PracticeSessionModel(
        lessonId: '3f2b8c1e-9d4a-4e7b-8a61-0c5d2f7e9b13',
        clientId: '9a1c7e52-4b3d-4f08-a6c9-1e2d3f405a67',
        score: 91.5,
        correctNotes: 100,
        totalNotes: 200,
        wrongNotes: 50,
        missedNotes: 50,
        averageTempo: 80,
        totalTimeSeconds: 300,
        errorsDetail: errors,
      );
      expect(utf8.encode(jsonEncode(model.toJson())).length, lessThan(5120));
    });
  });

  group('fromTelemetry', () {
    PracticeSessionModel build({
      required double tuning,
      required double rhythm,
      required double posture,
      PracticeScoreWeights? weights,
    }) => PracticeSessionModel.fromTelemetry(
      lessonId: 'l',
      tuningScore: tuning,
      rhythmScore: rhythm,
      postureScore: posture,
      correctNotes: 1,
      totalNotes: 1,
      wrongNotes: 0,
      missedNotes: 0,
      averageTempo: 60,
      totalTimeSeconds: 10,
      weights: weights ?? const PracticeScoreWeights(),
    );

    test('default weights are tuning 50%, rhythm 30%, posture 20%', () {
      expect(build(tuning: 100, rhythm: 0, posture: 0).score, 50);
      expect(build(tuning: 0, rhythm: 100, posture: 0).score, 30);
      expect(build(tuning: 0, rhythm: 0, posture: 100).score, 20);
      expect(build(tuning: 80, rhythm: 60, posture: 40).score, 66);
    });

    test('weights are configurable', () {
      final model = build(
        tuning: 100,
        rhythm: 0,
        posture: 0,
        weights: const PracticeScoreWeights(
          tuning: 0.2,
          rhythm: 0.5,
          posture: 0.3,
        ),
      );
      expect(model.score, 20);
    });

    test('component scores are clamped to 0..100', () {
      expect(build(tuning: 250, rhythm: 250, posture: 250).score, 100);
      expect(build(tuning: -5, rhythm: -5, posture: -5).score, 0);
    });

    test('rejects weights that do not add up to 1', () {
      expect(
        () => build(
          tuning: 50,
          rhythm: 50,
          posture: 50,
          weights: const PracticeScoreWeights(
            tuning: 0.5,
            rhythm: 0.5,
            posture: 0.5,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('generates a unique UUID client_id per session', () {
      final a = build(tuning: 1, rhythm: 1, posture: 1);
      final b = build(tuning: 1, rhythm: 1, posture: 1);
      expect(a.clientId, isNot(b.clientId));
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(a.clientId),
        isTrue,
      );
    });
  });
}
