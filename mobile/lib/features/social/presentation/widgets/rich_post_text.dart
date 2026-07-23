import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Renderiza el texto de un post/comentario con @menciones y #hashtags
/// clickeables (navegan al perfil / feed del hashtag).
class RichPostText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  /// Si se indica, el texto se recorta a `maxLines` con un botón "Ver más".
  final int? maxLines;

  const RichPostText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
  });

  @override
  State<RichPostText> createState() => _RichPostTextState();
}

class _RichPostTextState extends State<RichPostText> {
  static final _tokenRe = RegExp(r'(@[A-Za-z0-9_]{3,30}|#[A-Za-z0-9_]{1,100})');
  final List<TapGestureRecognizer> _recognizers = [];
  bool _expanded = false;

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _onTapToken(String token) {
    if (token.startsWith('@')) {
      context.push('/social/u/${token.substring(1)}');
    } else {
      context.push('/social/hashtag/${token.substring(1).toLowerCase()}');
    }
  }

  List<InlineSpan> _buildSpans(TextStyle linkStyle) {
    _clearRecognizers();
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _tokenRe.allMatches(widget.text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      }
      final token = m.group(0)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _onTapToken(token);
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: token, style: linkStyle, recognizer: recognizer));
      last = m.end;
    }
    if (last < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(last)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseStyle =
        widget.style ??
        TextStyle(color: cs.onSurface, fontSize: 14, height: 1.4);
    final linkStyle = baseStyle.copyWith(
      color: cs.primary,
      fontWeight: FontWeight.w600,
    );

    final textSpan = TextSpan(style: baseStyle, children: _buildSpans(linkStyle));

    if (widget.maxLines == null) {
      return Text.rich(textSpan);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: textSpan,
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        if (!overflows) {
          return Text.rich(textSpan);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              textSpan,
              maxLines: _expanded ? null : widget.maxLines,
              overflow: _expanded
                  ? TextOverflow.clip
                  : TextOverflow.ellipsis,
            ),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _expanded ? 'Ver menos' : 'Ver más',
                  style: baseStyle.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
