import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/note_sequence_model.dart';
import 'piano_guide_widget.dart' show computeWhiteKeyRange;

/// Vista "falling notes" / cascada (estilo Synthesia/Yousician): las notas caen
/// desde arriba hacia un teclado en la base. Como el motor de práctica es por
/// turnos (espera la nota correcta), la cascada se mueve según el PROGRESO
/// (currentPosition), no por reloj: la nota actual queda sobre la línea de
/// impacto y las siguientes se apilan encima. Incluye su propio teclado para
/// que las notas queden perfectamente alineadas con las teclas.
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
    final whiteKeys = computeWhiteKeyRange(
      notes.where((n) => !n.isRest).map((n) => n.note),
      2,
    );
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
            whiteKeys: whiteKeys,
            primary: cs.primary,
            secondary: cs.secondary,
            keyWhite: Colors.white,
            keyBlack: const Color(0xFF1A1A22),
            border: cs.surfaceContainerHighest,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

const Map<String, int> _semi = {
  'C': 0,
  'D': 2,
  'E': 4,
  'F': 5,
  'G': 7,
  'A': 9,
  'B': 11,
};
final RegExp _noteRe = RegExp(r'^([A-G])([#b]?)(-?\d+)');

int? _midi(String note) {
  final m = _noteRe.firstMatch(note);
  if (m == null) return null;
  var s = _semi[m.group(1)!]!;
  if (m.group(2) == '#') s++;
  if (m.group(2) == 'b') s--;
  return (int.parse(m.group(3)!) + 1) * 12 + s;
}

bool _isWhite(int m) => const [0, 2, 4, 5, 7, 9, 11].contains(m % 12);

class _FallingPainter extends CustomPainter {
  final List<NoteSequenceModel> notes;
  final double animPos;
  final int currentPosition;
  final String? currentExpectedNote;
  final List<String> whiteKeys;
  final Color primary, secondary, keyWhite, keyBlack, border;

  _FallingPainter({
    required this.notes,
    required this.animPos,
    required this.currentPosition,
    required this.currentExpectedNote,
    required this.whiteKeys,
    required this.primary,
    required this.secondary,
    required this.keyWhite,
    required this.keyBlack,
    required this.border,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (whiteKeys.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final keyboardH = math.min(96.0, h * 0.32);
    final hitY = h - keyboardH;
    final whiteW = w / whiteKeys.length;
    const spacing = 64.0;

    final firstWhiteMidi = _midi(whiteKeys.first);
    final lastWhiteMidi = _midi(whiteKeys.last);
    if (firstWhiteMidi == null || lastWhiteMidi == null) return;

    // Índice de tecla blanca para un midi blanco (cuántas blancas hay antes).
    int whiteIndexOf(int m) {
      var idx = 0;
      for (var k = firstWhiteMidi; k < m; k++) {
        if (_isWhite(k)) idx++;
      }
      return idx;
    }

    // Centro x + ancho de la nota (blancas centradas; negras en el borde).
    (double, double, bool) keyGeom(int m) {
      if (_isWhite(m)) {
        return ((whiteIndexOf(m) + 0.5) * whiteW, whiteW * 0.78, false);
      }
      // Negra: se apoya en el borde derecho de la blanca m-1.
      return ((whiteIndexOf(m - 1) + 1) * whiteW, whiteW * 0.58, true);
    }

    // 1) Notas que caen.
    final lookAhead = (hitY / spacing).ceil() + 2;
    final startI = math.max(0, animPos.floor() - 1);
    final endI = math.min(notes.length - 1, animPos.floor() + lookAhead);
    for (var i = startI; i <= endI; i++) {
      final n = notes[i];
      if (n.isRest) continue;
      final m = _midi(n.note);
      if (m == null || m < firstWhiteMidi || m > lastWhiteMidi) continue;
      final (cx, kw, isBlack) = keyGeom(m);
      final noteH = (n.duration * spacing).clamp(16.0, spacing * 3);
      final bottom = hitY - (i - animPos) * spacing;
      final top = bottom - noteH;
      if (bottom < 0 || top > hitY) continue;
      final isCurrent = i == currentPosition;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - kw / 2, top, cx + kw / 2, bottom - 2),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = isCurrent
              ? primary
              : (isBlack ? secondary : primary).withValues(alpha: 0.5),
      );
      if (isCurrent) {
        canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.85),
        );
      }
    }

    // Línea de impacto.
    canvas.drawLine(
      Offset(0, hitY),
      Offset(w, hitY),
      Paint()
        ..color = primary.withValues(alpha: 0.6)
        ..strokeWidth = 2,
    );

    // 2) Teclado en la base.
    final highlightMidi = currentExpectedNote == null
        ? null
        : _midi(currentExpectedNote!);
    for (var wi = 0; wi < whiteKeys.length; wi++) {
      final x = wi * whiteW;
      final isHi =
          highlightMidi != null && _midi(whiteKeys[wi]) == highlightMidi;
      final r = Rect.fromLTWH(x + 0.5, hitY, whiteW - 1, keyboardH);
      canvas.drawRect(r, Paint()..color = isHi ? primary : keyWhite);
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = border,
      );
    }
    for (var k = firstWhiteMidi; k <= lastWhiteMidi; k++) {
      if (_isWhite(k)) continue;
      final (cx, _, _) = keyGeom(k);
      final bw = whiteW * 0.58;
      final r = Rect.fromLTWH(cx - bw / 2, hitY, bw, keyboardH * 0.62);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        Paint()..color = highlightMidi == k ? primary : keyBlack,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FallingPainter old) =>
      old.animPos != animPos ||
      old.currentExpectedNote != currentExpectedNote ||
      old.currentPosition != currentPosition ||
      !identical(old.notes, notes) ||
      !identical(old.whiteKeys, whiteKeys);
}
