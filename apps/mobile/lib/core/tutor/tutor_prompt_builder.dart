import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/features/lessons/data/models/practice_session_model.dart';

/// Resumen consolidado de telemetría acústica y postural tras una sesión de práctica.
class PracticeSummary {
  final double score;
  final int correctNotes;
  final int totalNotes;
  final int wrongNotes;
  final int missedNotes;
  final double averageTempo;
  final int expectedTempo;
  final double tempoAccuracy;
  final double averageCentsDeviation;
  final double postureStabilityScore;
  final List<String> flaggedErrors;
  final double totalTimeSeconds;

  const PracticeSummary({
    required this.score,
    required this.correctNotes,
    required this.totalNotes,
    this.wrongNotes = 0,
    this.missedNotes = 0,
    this.averageTempo = 60.0,
    this.expectedTempo = 60,
    this.tempoAccuracy = 1.0,
    this.averageCentsDeviation = 0.0,
    this.postureStabilityScore = 1.0,
    this.flaggedErrors = const [],
    this.totalTimeSeconds = 0.0,
  });

  /// Construye un [PracticeSummary] a partir de un modelo de sesión [PracticeSessionModel].
  factory PracticeSummary.fromSession(
    PracticeSessionModel session, {
    double postureStabilityScore = 1.0,
    double averageCentsDeviation = 0.0,
  }) {
    final List<String> errors = [];
    if (session.errorsDetail != null) {
      for (final err in session.errorsDetail!) {
        final desc = err['error'] ?? err['type'] ?? err['note'];
        if (desc != null && desc.toString().isNotEmpty) {
          errors.add(desc.toString());
        }
      }
    }

    return PracticeSummary(
      score: session.score,
      correctNotes: session.correctNotes,
      totalNotes: session.totalNotes,
      wrongNotes: session.wrongNotes,
      missedNotes: session.missedNotes,
      averageTempo: session.averageTempo,
      expectedTempo: session.expectedTempo,
      tempoAccuracy: session.tempoAccuracy,
      averageCentsDeviation: averageCentsDeviation,
      postureStabilityScore: postureStabilityScore,
      flaggedErrors: errors,
      totalTimeSeconds: session.totalTimeSeconds,
    );
  }
}

/// Constructor de prompts pedagógicos estructurados para el modelo SLM local On-Device.
///
/// Convierte métricas cuantitativas de afinación, ritmo y postura en un prompt
/// conciso para guiar la generación de feedback pedagógico contextual.
class TutorPromptBuilder {
  /// Consejo pedagógico predeterminado ante timeouts o respuestas vacías del SLM.
  static const String defaultPedagogicalAdvice =
      '¡Buen esfuerzo! Recuerda mantener el flujo de aire constante y los hombros relajados.';

  const TutorPromptBuilder();

  /// Construye el prompt estructurado a partir del resumen de telemetría y del instrumento andino.
  String buildPrompt(PracticeSummary summary, InstrumentType instrument) {
    final instrumentName = _formatInstrumentName(instrument);
    final accuracyPercent = summary.totalNotes > 0
        ? ((summary.correctNotes / summary.totalNotes) * 100).toStringAsFixed(1)
        : '0.0';

    final buffer = StringBuffer();
    buffer.writeln(
      'Eres un maestro experto de música andina tradicional y tutor pedagógico.',
    );
    buffer.writeln(
      'Analiza la siguiente telemetría de ejecución musical y brinda un consejo breve,',
    );
    buffer.writeln('cálido y constructivo en español para el estudiante.');
    buffer.writeln('');
    buffer.writeln('--- TELEMETRÍA DE PRÁCTICA ---');
    buffer.writeln('Instrumento: $instrumentName');
    buffer.writeln('Puntaje: ${summary.score.toStringAsFixed(1)} / 100');
    buffer.writeln(
      'Notas acertadas: ${summary.correctNotes} de ${summary.totalNotes} ($accuracyPercent%)',
    );
    buffer.writeln(
      'Notas falladas: ${summary.wrongNotes}, notas omitidas: ${summary.missedNotes}',
    );
    buffer.writeln(
      'Desviación de afinación: ${summary.averageCentsDeviation.toStringAsFixed(1)} cents',
    );
    buffer.writeln(
      'Estabilidad postural: ${(summary.postureStabilityScore * 100).toStringAsFixed(1)}%',
    );
    buffer.writeln(
      'Tempo promedio: ${summary.averageTempo.toStringAsFixed(1)} BPM (Esperado: ${summary.expectedTempo} BPM)',
    );

    if (summary.flaggedErrors.isNotEmpty) {
      buffer.writeln(
        'Detalle de errores detectados: ${summary.flaggedErrors.join(', ')}',
      );
    }

    buffer.writeln('');
    buffer.writeln('--- INSTRUCCIÓN PEDAGÓGICA ---');
    buffer.writeln(
      'Genera exactamente 1 o 2 oraciones en español orientadas a mejorar la técnica de $instrumentName (embocadura, orificios, soplo suave, ataque o postura).',
    );
    buffer.writeln(
      'Sé empático, constructivo y mantén el consejo en menos de 50 palabras.',
    );

    return buffer.toString().trim();
  }

  String _formatInstrumentName(InstrumentType instrument) {
    switch (instrument) {
      case InstrumentType.quena:
        return 'Quena';
      case InstrumentType.zampona:
        return 'Zampoña';
      case InstrumentType.tarka:
        return 'Tarka';
    }
  }
}
