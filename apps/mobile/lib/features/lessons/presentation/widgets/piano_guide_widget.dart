import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Piano visual con teclas resaltadas. El rango de teclas se calcula del
/// conjunto de notas de la lección ([rangeNotes]): muestra desde la nota más
/// grave a la más aguda. Si el rango es ancho (varias octavas) se vuelve
/// scrolleable horizontalmente y hace auto-scroll a la nota activa.
class PianoGuideWidget extends StatefulWidget {
  final Set<String> highlightNotes;
  final Color? highlightColor;
  final Color correctColor;
  final Color? wrongColor;
  final String? activeNote;
  final String? wrongNote;
  final bool showLabels;

  /// Notas que usa la lección, para calcular el rango de octavas a dibujar.
  /// Si está vacío, cae a 2 octavas alrededor de C4.
  final Iterable<String> rangeNotes;

  /// Mínimo de octavas COMPLETAS a mostrar (piso realista por nivel). 2 = 25
  /// teclas (el teclado más chico real). El rango real será el mayor entre esto
  /// y el rango de la lección, siempre ajustado a octavas completas (C a C).
  final int minOctaves;

  const PianoGuideWidget({
    super.key,
    this.highlightNotes = const {},
    this.highlightColor,
    this.correctColor = AppTheme.success,
    this.wrongColor,
    this.activeNote,
    this.wrongNote,
    this.showLabels = true,
    this.rangeNotes = const [],
    this.minOctaves = 2,
  });

  @override
  State<PianoGuideWidget> createState() => _PianoGuideWidgetState();
}

class _PianoGuideWidgetState extends State<PianoGuideWidget> {
  final ScrollController _scroll = ScrollController();
  // Ancho mínimo de tecla blanca. Bajo a propósito para que 2 octavas (15
  // blancas / 25 teclas) entren completas en pantalla sin carrusel; el scroll
  // recién aparece con 3+ octavas.
  static const double _minKeyWidth = 20;
  static const double _height = 120;

  List<String> _whiteKeys = const [];
  double _keyWidth = _minKeyWidth;
  double _available = 0;

  @override
  void didUpdateWidget(PianoGuideWidget old) {
    super.didUpdateWidget(old);
    if (old.activeNote != widget.activeNote) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToActive() {
    final active = widget.activeNote;
    if (active == null || !_scroll.hasClients || _whiteKeys.isEmpty) return;
    final idx = _whiteIndexFor(active);
    if (idx < 0) return;
    final target = idx * _keyWidth + _keyWidth / 2 - _available / 2;
    final maxExtent = _scroll.position.maxScrollExtent;
    _scroll.animateTo(
      target.clamp(0.0, maxExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Índice de la tecla blanca que corresponde (o está debajo de) [note].
  int _whiteIndexFor(String note) {
    final base = _baseWhiteName(note);
    final exact = _whiteKeys.indexOf(base);
    if (exact >= 0) return exact;
    // Nota negra: ubicar la blanca inmediatamente inferior por MIDI.
    final m = _noteToMidi(note);
    if (m == null) return -1;
    var best = -1;
    var bestDiff = 1 << 30;
    for (var i = 0; i < _whiteKeys.length; i++) {
      final wm = _noteToMidi(_whiteKeys[i]);
      if (wm == null) continue;
      final d = (wm - m).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = i;
      }
    }
    return best;
  }

  List<String> _computeWhiteKeys() {
    final all = <String>{...widget.rangeNotes, ...widget.highlightNotes};
    if (widget.activeNote != null) all.add(widget.activeNote!);
    if (widget.wrongNote != null) all.add(widget.wrongNote!);
    return computeWhiteKeyRange(all, widget.minOctaves);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHighlight =
        widget.highlightColor ?? Theme.of(context).colorScheme.primary;
    final effectiveWrong =
        widget.wrongColor ?? Theme.of(context).colorScheme.error;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final whiteKeys = _computeWhiteKeys();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final keyWidth = math.max(_minKeyWidth, available / whiteKeys.length);
        final totalWidth = keyWidth * whiteKeys.length;

        _whiteKeys = whiteKeys;
        _keyWidth = keyWidth;
        _available = available;
        // Re-centrar en la nota activa tras el layout.
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());

        return SizedBox(
          height: _height,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: totalWidth <= available + 0.5
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            child: CustomPaint(
              size: Size(totalWidth, _height),
              painter: _PianoPainter(
                whiteNotes: whiteKeys,
                keyWidth: keyWidth,
                highlightNotes: widget.highlightNotes,
                highlightColor: effectiveHighlight,
                correctColor: widget.correctColor,
                wrongColor: effectiveWrong,
                whiteKeyColor: isDark
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.white,
                borderColor: isDark
                    ? Theme.of(context).dividerColor
                    : Theme.of(context).colorScheme.outlineVariant,
                blackKeyColor: isDark
                    ? Theme.of(context).colorScheme.outline
                    : Theme.of(context).colorScheme.onSurface,
                activeNote: widget.activeNote,
                wrongNote: widget.wrongNote,
                showLabels: widget.showLabels,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Teclas blancas de un teclado REALISTA para mostrar [notes]: ajusta el rango
/// a octavas completas (de C a C) y garantiza un mínimo de [minOctaves]
/// expandiendo simétricamente, dentro de C1–C8. Pública para tests.
List<String> computeWhiteKeyRange(Iterable<String> notes, int minOctaves) {
  final midis = <int>[];
  for (final n in notes) {
    final m = _noteToMidi(n);
    if (m != null) midis.add(m);
  }
  int minM, maxM;
  if (midis.isEmpty) {
    minM = 60; // C4
    maxM = 71; // B4
  } else {
    minM = midis.reduce(math.min);
    maxM = midis.reduce(math.max);
  }

  // Ajustar a octavas completas: C de la octava de minM, hasta el C en/arriba
  // de maxM.
  var startC = (minM ~/ 12) * 12;
  var endC = (maxM % 12 == 0) ? maxM : ((maxM ~/ 12) + 1) * 12;

  const lowLimit = 24; // C1
  const highLimit = 108; // C8
  // Expandir simétricamente hasta el mínimo de octavas.
  var down = true;
  while ((endC - startC) ~/ 12 < minOctaves) {
    if (down && startC - 12 >= lowLimit) {
      startC -= 12;
    } else if (endC + 12 <= highLimit) {
      endC += 12;
    } else if (startC - 12 >= lowLimit) {
      startC -= 12;
    } else {
      break;
    }
    down = !down;
  }

  final whites = <String>[];
  for (var m = startC; m <= endC; m++) {
    if (_isWhite(m)) whites.add(_midiName(m));
  }
  return whites;
}

// --- Utilidades de notas ---
int? _noteToMidi(String note) {
  final m = RegExp(r'^([A-G])([#b]?)(-?\d+)').firstMatch(note);
  if (m == null) return null;
  const semi = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
  var s = semi[m.group(1)!]!;
  if (m.group(2) == '#') s++;
  if (m.group(2) == 'b') s--;
  return (int.parse(m.group(3)!) + 1) * 12 + s;
}

String _midiName(int m) {
  const names = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  return '${names[m % 12]}${m ~/ 12 - 1}';
}

bool _isWhite(int m) => const [0, 2, 4, 5, 7, 9, 11].contains(m % 12);

/// Nombre de la tecla blanca de [note] (quita la alteración). "C#4" → "C4".
String _baseWhiteName(String note) {
  final m = RegExp(r'^([A-G])[#b]?(-?\d+)').firstMatch(note);
  return m == null ? note : '${m.group(1)}${m.group(2)}';
}

class _PianoPainter extends CustomPainter {
  final List<String> whiteNotes;
  final double keyWidth;
  final Set<String> highlightNotes;
  final Color highlightColor;
  final Color correctColor;
  final Color wrongColor;
  final String? activeNote;
  final String? wrongNote;
  final bool showLabels;
  final Color whiteKeyColor;
  final Color borderColor;
  final Color blackKeyColor;

  _PianoPainter({
    required this.whiteNotes,
    required this.keyWidth,
    required this.highlightNotes,
    required this.highlightColor,
    required this.correctColor,
    required this.wrongColor,
    required this.whiteKeyColor,
    required this.borderColor,
    required this.blackKeyColor,
    this.activeNote,
    this.wrongNote,
    required this.showLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final whiteKeyHeight = size.height;
    final blackKeyWidth = keyWidth * 0.6;
    final blackKeyHeight = whiteKeyHeight * 0.6;

    // Teclas blancas
    for (var i = 0; i < whiteNotes.length; i++) {
      final note = whiteNotes[i];
      final x = i * keyWidth;
      final rect = Rect.fromLTWH(x, 0, keyWidth - 1, whiteKeyHeight);

      Color color = whiteKeyColor;
      if (note == activeNote) {
        color = highlightColor;
      } else if (note == wrongNote) {
        color = wrongColor;
      } else if (highlightNotes.contains(note)) {
        color = highlightColor.withValues(alpha: 0.4);
      }

      final paint = Paint()..color = color;
      final rrect = RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      );
      canvas.drawRRect(rrect, paint);

      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRRect(rrect, borderPaint);

      if (note == activeNote) {
        final glowPaint = Paint()
          ..color = highlightColor.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
        canvas.drawRRect(rrect, glowPaint);
      }

      if (showLabels && highlightNotes.contains(note)) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: note,
            style: TextStyle(
              color: note == activeNote ? Colors.white : blackKeyColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(
            x + (keyWidth - textPainter.width) / 2,
            whiteKeyHeight - textPainter.height - 4,
          ),
        );
      }
    }

    // Teclas negras (entre blancas consecutivas, salvo después de E y B)
    for (var i = 0; i < whiteNotes.length - 1; i++) {
      final baseName = whiteNotes[i];
      final baseNote = baseName.substring(0, 1);
      final octave = baseName.substring(1);
      if (baseNote == 'E' || baseNote == 'B') continue;

      final sharpName = '$baseNote#$octave';
      final x = (i + 1) * keyWidth - blackKeyWidth / 2;
      final rect = Rect.fromLTWH(x, 0, blackKeyWidth, blackKeyHeight);

      Color color = blackKeyColor;
      if (sharpName == activeNote) {
        color = highlightColor;
      } else if (sharpName == wrongNote) {
        color = wrongColor;
      } else if (highlightNotes.contains(sharpName)) {
        color = highlightColor.withValues(alpha: 0.5);
      }

      final paint = Paint()..color = color;
      final rrect = RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      );
      canvas.drawRRect(rrect, paint);

      if (sharpName == activeNote) {
        final glowPaint = Paint()
          ..color = highlightColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
        canvas.drawRRect(rrect, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PianoPainter old) =>
      old.activeNote != activeNote ||
      old.wrongNote != wrongNote ||
      old.highlightNotes != highlightNotes ||
      old.whiteNotes != whiteNotes ||
      old.keyWidth != keyWidth;
}
