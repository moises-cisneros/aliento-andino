import 'package:flutter/material.dart';

import '../data/tutor_repository.dart';
import 'tutor_action_executor.dart';

/// Hoja de conversación con el agente tutor "Vivi".
class TutorSheet extends StatefulWidget {
  final TutorRepository repository;
  final TutorActionExecutor executor;
  /// Ruta donde estaba el usuario al abrir el tutor (para que Vivi no navegue
  /// de más y pueda decir "ya estás acá").
  final String? currentRoute;

  const TutorSheet({
    super.key,
    required this.repository,
    required this.executor,
    this.currentRoute,
  });

  @override
  State<TutorSheet> createState() => _TutorSheetState();
}

class _TutorSheetState extends State<TutorSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  /// La conversación vive en el repositorio (persiste al cerrar el chat).
  List<TutorMessage> get _messages => widget.repository.conversation;

  @override
  void initState() {
    super.initState();
    // Si ya hay conversación previa, abrir mostrando el final.
    if (_messages.isNotEmpty) _scrollToBottom();
  }

  static const _suggestions = [
    '¿Cómo practico una lección?',
    '¿Dónde veo mi progreso?',
    '¿Cómo guardo una publicación?',
    'Recomiéndame qué practicar',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final message = text.trim();
    if (message.isEmpty || _sending) return;

    setState(() {
      _messages.add(TutorMessage(role: 'user', text: message));
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      // El historial que mandamos NO incluye el mensaje recién agregado.
      final history = _messages
          .sublist(0, _messages.length - 1)
          .toList(growable: false);
      final reply = await widget.repository.chat(
        message,
        history,
        currentRoute: widget.currentRoute,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(TutorMessage(role: 'model', text: reply.reply));
        _sending = false;
      });
      _scrollToBottom();
      // Ejecutar las acciones (navegar/resaltar). Mostramos la respuesta un
      // momento para que el usuario la lea, luego cerramos y ejecutamos.
      if (reply.actions.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 1300));
        if (!mounted) return;
        Navigator.of(context).maybePop();
        await widget.executor.run(reply.actions);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const TutorMessage(
            role: 'model',
            text: 'Tuve un problema para responder. Probá de nuevo.',
          ),
        );
        _sending = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                _header(cs),
                Expanded(child: _body(cs, scrollController)),
                _inputBar(cs),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: cs.primary.withValues(alpha: 0.15),
            child: Icon(Icons.auto_awesome, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vivi · Tutor IA',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Te enseño a usar la app',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Theme.of(context).hintColor),
              tooltip: 'Limpiar conversación',
              onPressed: () =>
                  setState(() => widget.repository.clearConversation()),
            ),
          IconButton(
            icon: Icon(Icons.close, color: Theme.of(context).hintColor),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _body(ColorScheme cs, ScrollController scrollController) {
    if (_messages.isEmpty) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '¡Hola! Soy Vivi 🎹 Preguntame cómo hacer algo en la app y te llevo '
            'al lugar correcto.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .map(
                  (s) => ActionChip(
                    label: Text(s),
                    backgroundColor: cs.surfaceContainerHigh,
                    labelStyle: TextStyle(color: cs.onSurface, fontSize: 13),
                    onPressed: () => _send(s),
                  ),
                )
                .toList(),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _messages.length) {
          return _bubble(cs, isUser: false, text: '…');
        }
        final m = _messages[index];
        return _bubble(cs, isUser: m.role == 'user', text: m.text);
      },
    );
  }

  Widget _bubble(ColorScheme cs, {required bool isUser, required String text}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : cs.onSurface,
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _inputBar(ColorScheme cs) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: TextStyle(color: cs.onSurface),
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: 'Escribí tu pregunta…',
                  hintStyle: TextStyle(color: Theme.of(context).hintColor),
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : () => _send(_controller.text),
              icon: const Icon(Icons.send),
              style: IconButton.styleFrom(backgroundColor: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}
