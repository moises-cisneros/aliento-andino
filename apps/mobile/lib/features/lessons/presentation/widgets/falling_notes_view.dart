import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/note_sequence_model.dart';

/// Vista "falling notes" / cascada para aerófonos andinos (Quena, Zampoña, Tarka).
///
/// Las notas caen desde arriba hacia una línea de impacto / target bar en la base.
/// Como el motor de práctica es por turnos (espera la nota correcta), la cascada
/// se mueve según el progreso musical ([currentPosition]), no por reloj.
/// La nota actual se alinea sobre la línea de impacto con indicación de cents y frecuencia.
class FallingNotesView extends StatelessWidget {
  final List<NoteSequenceModel> notes;
  final int currentPosition;
  final String? currentExpectedNote;

  const FallingNotesView({
    super.key,
    required this.notes,
    required this.currentPosition,
    this.currentExpectedNote,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Calcular rango MIDI de las notas de la lección
    final midis = notes
        .where((n) => !n.isRest)
        .map((n) => _midi(n.note))
        .whereType<int>()
        .toList();

    final int minMidi = midis.isNotEmpty ? midis.reduce(math.min) : 67; // Sol4
    final int maxMidi = midis.isNotEmpty ? midis.reduce(math.max) : 79; // Sol5

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: currentPosition.toDouble()),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, animPos, _) {
        return CustomPaint(
          painter: _FallingPainter(
            notes: notes,
            animPos: animPos,
            currentPosition: currentPosition,
            currentExpectedNote: currentExpectedNote,
            minMidi: minMidi,
            maxMidi: maxMidi,
            primary: cs.primary,
            secondary: cs.secondary,
            surface: cs.surfaceContainerHighest,
            border: cs.outlineVariant,
            textColor: cs.onSurface,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

const Map<String, int> _semi = {
  'C': 0,
  'DO': 0,
  'D': 2,
  'RE': 2,
  'E': 4,
  'MI': 4,
  'F': 5,
  'FA': 5,
  'G': 7,
  'SOL': 7,
  'A': 9,
  'LA': 9,
  'B': 11,
  'SI': 11,
};

final RegExp _noteRe = RegExp(r'^([A-Za-z]+)([#b]?)(-?\d+)');

int? _midi(String note) {
  final m = _noteRe.firstMatch(note.trim());
  if (m == null) return null;
  final root = m.group(1)!.toUpperCase();
  final s = _semi[root];
  if (s == null) return null;
  var semitone = s;
  if (m.group(2) == '#') semitone++;
  if (m.group(2) == 'b') semitone--;
  final octave = int.tryParse(m.group(3)!);
  if (octave == null) return null;
  return (octave + 1) * 12 + semitone;
}

double? _midiToFreq(int? midi) {
  if (midi == null) return null;
  return 440.0 * math.pow(2.0, (midi - 69) / 12.0);
}

class _FallingPainter extends CustomPainter {
  final List<NoteSequenceModel> notes;
  final double animPos;
  final int currentPosition;
  final String? currentExpectedNote;
  final int minMidi;
  final int maxMidi;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color border;
  final Color textColor;

  _FallingPainter({
    required this.notes,
    required this.animPos,
    required this.currentPosition,
    required this.currentExpectedNote,
    required this.minMidi,
    required this.maxMidi,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.border,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Altura de la barra de impacto en la base
    final targetBarH = math.min(64.0, h * 0.22);
    final hitY = h - targetBarH;
    const spacing = 64.0;

    // Rango extendido para dar márgenes a los lados
    final rangeMin = minMidi - 1;
    final rangeMax = math.max(minMidi + 5, maxMidi + 1);
    final totalSpan = math.max(1, rangeMax - rangeMin);

    const padding = 20.0;
    final usableW = w - (padding * 2);

    double xForMidi(int m) {
      final t = ((m - rangeMin) / totalSpan).clamp(0.0, 1.0);
      return padding + (t * usableW);
    }

    final noteWidth = (usableW / (totalSpan + 1)).clamp(28.0, 56.0);

    // 1) Guías de pistas verticales tenues
    final lanePaint = Paint()
      ..color = border.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    for (var m = rangeMin; m <= rangeMax; m++) {
      final lx = xForMidi(m);
      canvas.drawLine(Offset(lx, 0), Offset(lx, hitY), lanePaint);
    }

    // 2) Notas que caen
    final lookAhead = (hitY / spacing).ceil() + 2;
    final startI = math.max(0, animPos.floor() - 1);
    final endI = math.min(notes.length - 1, animPos.floor() + lookAhead);

    for (var i = startI; i <= endI; i++) {
      final n = notes[i];
      if (n.isRest) continue;
      final m = _midi(n.note);
      if (m == null) continue;

      final cx = xForMidi(m);
      final noteH = (n.duration * spacing).clamp(24.0, spacing * 3);
      final bottom = hitY - (i - animPos) * spacing;
      final top = bottom - noteH;
      if (bottom < 0 || top > hitY) continue;

      final isCurrent = i == currentPosition;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - noteWidth / 2, top, cx + noteWidth / 2, bottom - 2),
        const Radius.circular(8),
      );

      // Sombra para la nota actual
      if (isCurrent) {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = primary.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }

      // Cuerpo de la nota
      canvas.drawRRect(
        rect,
        Paint()
          ..color = isCurrent ? primary : secondary.withValues(alpha: 0.65),
      );

      // Borde de la nota
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCurrent ? 2.0 : 1.0
          ..color = isCurrent
              ? Colors.white.withValues(alpha: 0.9)
              : border.withValues(alpha: 0.4),
      );

      // Texto con el nombre de la nota adentro del bloque
      if (noteH >= 20) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: n.note,
            style: TextStyle(
              color: Colors.white,
              fontSize: (noteWidth * 0.38).clamp(10.0, 14.0),
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: noteWidth);

        textPainter.paint(
          canvas,
          Offset(
            cx - (textPainter.width / 2),
            (top + bottom - textPainter.height) / 2,
          ),
        );
      }
    }

    // 3) Barra de impacto limpia para aerófonos andinos (sin teclado de piano)
    final barRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, hitY, w, targetBarH),
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
    );

    // Fondo de la target bar
    canvas.drawRRect(barRect, Paint()..color = surface.withValues(alpha: 0.95));

    // Borde de la target bar
    canvas.drawRRect(
      barRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = border.withValues(alpha: 0.3),
    );

    // Línea de impacto luminosa en hitY
    canvas.drawLine(
      Offset(0, hitY),
      Offset(w, hitY),
      Paint()
        ..color = primary
        ..strokeWidth = 3.0,
    );

    // Indicador / retícula de la nota esperada
    final expectedMidi = currentExpectedNote != null
        ? _midi(currentExpectedNote!)
        : null;

    if (expectedMidi != null) {
      final targetX = xForMidi(expectedMidi);

      // Resplandor en el punto de impacto
      canvas.drawCircle(
        Offset(targetX, hitY),
        10.0,
        Paint()
          ..color = primary.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      canvas.drawCircle(
        Offset(targetX, hitY),
        4.0,
        Paint()..color = Colors.white,
      );
    }

    // 4) Texto de afinación y nota esperada en la target bar
    final freq = _midiToFreq(expectedMidi);
    final freqStr = freq != null ? '${freq.toStringAsFixed(1)} Hz' : '';
    final label = currentExpectedNote != null
        ? 'Nota: $currentExpectedNote  ·  $freqStr  ·  ±15 cents'
        : 'Esperando nota…';

    final barTextPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 16);

    barTextPainter.paint(
      canvas,
      Offset(
        (w - barTextPainter.width) / 2,
        hitY + (targetBarH - barTextPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _FallingPainter old) =>
      old.animPos != animPos ||
      old.currentExpectedNote != currentExpectedNote ||
      old.currentPosition != currentPosition ||
      old.minMidi != minMidi ||
      old.maxMidi != maxMidi ||
      !identical(old.notes, notes);
}
