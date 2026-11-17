import 'package:mobile/features/lessons/data/models/practice_session_model.dart';

PracticeSessionModel historySession(
  String id, {
  double score = 80,
  String? createdAt = '2026-11-10T10:00:00Z',
  String? instrument = 'quena',
  String title = 'Escala de Re',
}) {
  return PracticeSessionModel(
    id: id,
    userId: 'usr-1',
    lessonId: 'les-1',
    score: score,
    correctNotes: 8,
    totalNotes: 10,
    wrongNotes: 1,
    missedNotes: 1,
    averageTempo: 80,
    expectedTempo: 80,
    tempoAccuracy: 95,
    totalTimeSeconds: 30,
    createdAt: createdAt,
    lessonTitle: title,
    lessonInstrument: instrument,
  );
}

Map<String, dynamic> historyPage(
  List<PracticeSessionModel> items, {
  int page = 1,
  int pages = 1,
}) => {
  'items': items,
  'total': items.length,
  'page': page,
  'size': 20,
  'pages': pages,
};
