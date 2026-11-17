import 'package:flutter/material.dart';

import '../../data/models/note_sequence_model.dart';

/// Vista de **notación en pentagrama** (sheet music) sobre un pentagrama doble
/// (clave de sol + clave de fa). Renderiza la secuencia de la lección como
/// cabezas de nota colocadas por su posición diatónica (letra + octava), con
/// líneas adicionales (ledger lines), alteraciones (♯/♭) y plicas.
///
/// Dos modos según [currentPosition]:
///  - `null`  → vista **estática** desplazable a mano (para el detalle de la
///    lección): muestra toda la partitura de izquierda a derecha.
///  - no-null → vista **en vivo** (durante la práctica): las columnas se
///    desplazan para mantener la nota actual sobre una "línea de tiempo" fija;
///    la columna actual se resalta y las pasadas se atenúan. El índice es el
///    mismo `currentPosition` (índice plano) que usa el motor por turnos.
class StaffView extends StatelessWidget {
  final List<NoteSequenceModel> notes;
  final int? currentPosition;
  final double height;

  const StaffView({
    super.key,
    required this.notes,
    this.currentPosition,
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cols = _buildColumns(notes);

    // Geometría base (consistente entre build y painter). El divisor 18 deja
    // margen inferior suficiente para notas graves con líneas adicionales
    // (p.ej. Do2 = 2 interlíneas bajo la clave de fa) sin recortar la cabeza.
    final lineGap = (height / 18).clamp(7.0, 14.0);
    final colWidth = lineGap * 3.4;
    final leftPad = lineGap * 4.8;

    final palette = _StaffPalette(
      line: cs.onSurfaceVariant.withValues(alpha: 0.55),
      head: cs.onSurface,
      past: cs.onSurfaceVariant.withValues(alpha: 0.45),
      current: cs.primary,
      highlight: cs.primary.withValues(alpha: 0.10),
      clef: cs.onSurface.withValues(alpha: 0.7),
      rest: cs.onSurfaceVariant.withValues(alpha: 0.5),
    );

    // ── Modo estático ────────────────────────────────────────────────────
    if (currentPosition == null) {
      final totalWidth = leftPad + cols.length * colWidth + colWidth;
      return SizedBox(
        height: height,
        child: cols.isEmpty
            ? const SizedBox.shrink()
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: CustomPaint(
                  size: Size(totalWidth.clamp(0, double.infinity), height),
                  painter: _StaffPainter(
                    cols: cols,
                    lineGap: lineGap,
                    colWidth: colWidth,
                    leftPad: leftPad,
                    animColPos: -1,
                    currentCol: -1,
                    palette: palette,
                  ),
                ),
              ),
      );
    }

    // ── Modo en vivo ─────────────────────────────────────────────────────
    final currentCol = _colOfPosition(cols, currentPosition!);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: currentCol.toDouble()),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (context, animCol, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _StaffPainter(
            cols: cols,
            lineGap: lineGap,
            colWidth: colWidth,
            leftPad: leftPad,
            animColPos: animCol,
            currentCol: currentCol,
            palette: palette,
          ),
        );
      },
    );
  }
}

// ── Modelo interno ──────────────────────────────────────────────────────────

/// Una columna vertical de la partitura: un acorde (varias cabezas) o una nota,
/// o un silencio. Cubre el rango de índices [firstIdx, lastIdx] de la lista
/// plana (para mapear el cursor `currentPosition`).
class _Col {
  final List<_Head> heads;
  final bool isRest;
  final int firstIdx;
  final int lastIdx;
  const _Col(this.heads, this.isRest, this.firstIdx, this.lastIdx);
}

/// Una cabeza de nota ya resuelta a coordenadas musicales.
class _Head {
  final int step; // paso diatónico = octava*7 + índiceLetra (C=0..B=6)
  final int accidental; // -1 bemol, 0 natural, +1 sostenido
  final double duration; // en tiempos (para abierta/cerrada)
  final bool treble; // true = clave de sol, false = clave de fa
  const _Head(this.step, this.accidental, this.duration, this.treble);
}

const Map<String, int> _letterIndex = {
  'C': 0,
  'D': 1,
  'E': 2,
  'F': 3,
  'G': 4,
  'A': 5,
  'B': 6,
};
const Map<String, int> _letterSemi = {
  'C': 0,
  'D': 2,
  'E': 4,
  'F': 5,
  'G': 7,
  'A': 9,
  'B': 11,
};
final RegExp _noteRe = RegExp(r'^([A-G])([#b]?)(-?\d+)');

/// Parsea el nombre de nota directamente (preserva letra+alteración escritas,
/// p.ej. "Bb3" cae en la línea de SI con bemol, no en LA♯).
_Head? _parseHead(NoteSequenceModel n) {
  final m = _noteRe.firstMatch(n.note);
  if (m == null) return null;
  final letter = m.group(1)!;
  final acc = m.group(2)!;
  final octave = int.parse(m.group(3)!);
  final step = octave * 7 + _letterIndex[letter]!;
  final accidental = acc == '#'
      ? 1
      : acc == 'b'
      ? -1
      : 0;
  var semi = _letterSemi[letter]!;
  if (acc == '#') semi++;
  if (acc == 'b') semi--;
  final midi = (octave + 1) * 12 + semi;
  // Clave: mano si está, si no por altura (Do central = clave de sol).
  final treble = n.hand == 'right'
      ? true
      : n.hand == 'left'
      ? false
      : midi >= 60;
  return _Head(step, accidental, n.duration, treble);
}

/// Agrupa la lista plana en columnas: cada `chordGroup` consecutivo es una
/// columna (acorde), cada silencio una columna propia, el resto notas sueltas.
List<_Col> _buildColumns(List<NoteSequenceModel> notes) {
  final cols = <_Col>[];
  var i = 0;
  while (i < notes.length) {
    final n = notes[i];
    if (n.isRest) {
      cols.add(_Col(const [], true, i, i));
      i++;
      continue;
    }
    if (n.isChord && n.chordGroup != null) {
      final g = n.chordGroup;
      final heads = <_Head>[];
      var j = i;
      while (j < notes.length &&
          notes[j].isChord &&
          notes[j].chordGroup == g &&
          !notes[j].isRest) {
        final h = _parseHead(notes[j]);
        if (h != null) heads.add(h);
        j++;
      }
      cols.add(_Col(heads, heads.isEmpty, i, j - 1));
      i = j;
    } else {
      final h = _parseHead(n);
      cols.add(_Col(h == null ? const [] : [h], h == null, i, i));
      i++;
    }
  }
  return cols;
}

/// Índice de la columna que contiene el índice plano [pos]. Si [pos] está más
/// allá del final, devuelve `cols.length`.
int _colOfPosition(List<_Col> cols, int pos) {
  for (var k = 0; k < cols.length; k++) {
    if (pos <= cols[k].lastIdx) return k;
  }
  return cols.length;
}

// ── Paleta (CustomPainter no tiene BuildContext) ────────────────────────────

class _StaffPalette {
  final Color line;
  final Color head;
  final Color past;
  final Color current;
  final Color highlight;
  final Color clef;
  final Color rest;
  const _StaffPalette({
    required this.line,
    required this.head,
    required this.past,
    required this.current,
    required this.highlight,
    required this.clef,
    required this.rest,
  });
}

// ── Painter ─────────────────────────────────────────────────────────────────

class _StaffPainter extends CustomPainter {
  final List<_Col> cols;
  final double lineGap;
  final double colWidth;
  final double leftPad;
  final double animColPos; // fraccional (vivo) o -1 (estático)
  final int currentCol; // -1 en estático
  final _StaffPalette palette;

  _StaffPainter({
    required this.cols,
    required this.lineGap,
    required this.colWidth,
    required this.leftPad,
    required this.animColPos,
    required this.currentCol,
    required this.palette,
  });

  bool get _live => animColPos >= 0;

  // Pasos diatónicos de referencia (línea inferior de cada pentagrama).
  static const int _trebleBottomStep = 30; // E4
  static const int _bassBottomStep = 18; // G2
  static const int _trebleTopLine = 38; // F5
  static const int _trebleBottomLine = 30; // E4
  static const int _bassTopLine = 26; // A3
  static const int _bassBottomLine = 18; // G2
  static const int _trebleMidLine = 34; // B4
  static const int _bassMidLine = 22; // D3

  double get _topPad => lineGap * 2;
  double get _trebleTopY => _topPad;
  double get _trebleBottomY => _topPad + 4 * lineGap;
  double get _interGap => lineGap * 5;
  double get _bassTopY => _trebleBottomY + _interGap;
  double get _bassBottomY => _bassTopY + 4 * lineGap;

  double _noteY(int step, bool treble) {
    if (treble) {
      return _trebleBottomY - (step - _trebleBottomStep) * (lineGap / 2);
    }
    return _bassBottomY - (step - _bassBottomStep) * (lineGap / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = palette.line
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    // 1) Líneas de ambos pentagramas a lo ancho.
    for (var k = 0; k < 5; k++) {
      final ty = _trebleTopY + k * lineGap;
      canvas.drawLine(Offset(0, ty), Offset(size.width, ty), linePaint);
      final by = _bassTopY + k * lineGap;
      canvas.drawLine(Offset(0, by), Offset(size.width, by), linePaint);
    }

    // 2) Barra/llave izquierda uniendo el sistema (grand staff).
    final brace = Paint()
      ..color = palette.line
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(leftPad, _trebleTopY),
      Offset(leftPad, _bassBottomY),
      brace,
    );

    // 3) Claves (glifos musicales Unicode).
    _drawClef(canvas, '\u{1D11E}', _noteY(_trebleMidLine, true), lineGap * 5.2);
    _drawClef(canvas, '\u{1D122}', _noteY(_bassMidLine, false), lineGap * 3.0);

    // 4) Línea de tiempo (playhead) en vivo. El clamp se protege: num.clamp
    //    lanza si lowerLimit > upperLimit (viewport más angosto que la clave).
    double playheadX = 0;
    if (_live) {
      final lo = leftPad + colWidth;
      playheadX = size.width <= lo
          ? lo
          : (leftPad + (size.width - leftPad) * 0.28).clamp(lo, size.width);
      final ph = Paint()
        ..color = palette.current.withValues(alpha: 0.35)
        ..strokeWidth = 2.0;
      canvas.drawLine(
        Offset(playheadX, _trebleTopY - lineGap),
        Offset(playheadX, _bassBottomY + lineGap),
        ph,
      );
    }

    // 5) Columnas. Recortar el área de notas para no pisar las claves.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(leftPad, 0, size.width, size.height));
    for (var c = 0; c < cols.length; c++) {
      final double cx = _live
          ? playheadX + (c - animColPos) * colWidth
          : leftPad + c * colWidth + colWidth / 2;
      if (_live && (cx < leftPad - colWidth || cx > size.width + colWidth)) {
        continue; // fuera de vista
      }
      _drawColumn(canvas, cols[c], c, cx);
    }
    canvas.restore();
  }

  void _drawColumn(Canvas canvas, _Col col, int index, double cx) {
    // Color según estado (vivo): pasada / actual / futura.
    Color color = palette.head;
    if (_live) {
      if (index == currentCol) {
        color = palette.current;
        // Resaltado de la columna actual (detrás de las notas).
        final hl = Paint()..color = palette.highlight;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              cx - colWidth * 0.45,
              _trebleTopY - lineGap,
              cx + colWidth * 0.45,
              _bassBottomY + lineGap,
            ),
            const Radius.circular(6),
          ),
          hl,
        );
      } else if (index < currentCol) {
        color = palette.past;
      }
    }

    if (col.isRest || col.heads.isEmpty) {
      _drawRest(canvas, cx);
      return;
    }
    for (final h in col.heads) {
      _drawHead(canvas, h, cx, color);
    }
  }

  void _drawHead(Canvas canvas, _Head h, double cx, Color color) {
    final y = _noteY(h.step, h.treble);
    final rx = lineGap * 0.66;
    final ry = lineGap * 0.5;

    // Líneas adicionales (ledger lines).
    final ledger = Paint()
      ..color = palette.line
      ..strokeWidth = 1.0;
    _drawLedgers(canvas, h.step, h.treble, cx, ledger);

    // Cabeza: rellena (negra/corchea) si dura < 2 tiempos, abierta si no.
    final filled = h.duration < 2;
    final headPaint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..isAntiAlias = true;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, y), width: rx * 2, height: ry * 2),
      headPaint,
    );

    // Plica (no en redonda, dur >= 4).
    if (h.duration < 4) {
      final midLine = h.treble ? _trebleMidLine : _bassMidLine;
      final stemUp = h.step < midLine; // por debajo del centro → plica arriba
      final stemPaint = Paint()
        ..color = color
        ..strokeWidth = 1.4;
      final stemLen = lineGap * 3;
      if (stemUp) {
        canvas.drawLine(
          Offset(cx + rx, y),
          Offset(cx + rx, y - stemLen),
          stemPaint,
        );
      } else {
        canvas.drawLine(
          Offset(cx - rx, y),
          Offset(cx - rx, y + stemLen),
          stemPaint,
        );
      }
    }

    // Alteración a la izquierda de la cabeza.
    if (h.accidental != 0) {
      _drawText(
        canvas,
        h.accidental > 0 ? '♯' : '♭', // ♯ / ♭
        Offset(cx - rx - lineGap * 1.1, y),
        lineGap * 2.0,
        color,
        centerV: true,
      );
    }
  }

  void _drawLedgers(Canvas canvas, int step, bool treble, double cx, Paint p) {
    final topLine = treble ? _trebleTopLine : _bassTopLine;
    final bottomLine = treble ? _trebleBottomLine : _bassBottomLine;
    final halfW = lineGap * 1.1;
    if (step > topLine) {
      for (var ls = topLine + 2; ls <= step; ls += 2) {
        final y = _noteY(ls, treble);
        canvas.drawLine(Offset(cx - halfW, y), Offset(cx + halfW, y), p);
      }
    } else if (step < bottomLine) {
      for (var ls = bottomLine - 2; ls >= step; ls -= 2) {
        final y = _noteY(ls, treble);
        canvas.drawLine(Offset(cx - halfW, y), Offset(cx + halfW, y), p);
      }
    }
  }

  void _drawRest(Canvas canvas, double cx) {
    // Silencio simple: marca en la línea central del pentagrama de sol.
    final y = _noteY(_trebleMidLine, true);
    final p = Paint()
      ..color = palette.rest
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(cx - lineGap * 0.5, y),
      Offset(cx + lineGap * 0.5, y),
      p,
    );
  }

  void _drawClef(Canvas canvas, String glyph, double centerY, double fontSize) {
    _drawText(
      canvas,
      glyph,
      Offset(leftPad * 0.18, centerY),
      fontSize,
      palette.clef,
      centerV: true,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset at,
    double fontSize,
    Color color, {
    bool centerV = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          // Las claves son glifos musicales SMP (U+1D11E/U+1D122): pedir
          // fuentes con cobertura para evitar tofu en dispositivos sin ellas.
          fontFamilyFallback: const [
            'Noto Music',
            'Noto Sans Symbols2',
            'Noto Sans Symbols',
            'Symbola',
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dy = centerV ? at.dy - tp.height / 2 : at.dy;
    tp.paint(canvas, Offset(at.dx, dy));
  }

  @override
  bool shouldRepaint(covariant _StaffPainter old) {
    return old.animColPos != animColPos ||
        old.currentCol != currentCol ||
        !identical(old.cols, cols) ||
        old.lineGap != lineGap ||
        old.colWidth != colWidth ||
        old.palette != palette;
  }
}
