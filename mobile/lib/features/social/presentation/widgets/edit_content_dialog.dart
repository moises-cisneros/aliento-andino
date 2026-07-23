import 'package:flutter/material.dart';

/// Diálogo reutilizable para editar el contenido de un post o comentario.
/// Devuelve el nuevo texto (trim) al confirmar, o `null` si se cancela / no cambió.
Future<String?> showEditContentDialog(
  BuildContext context, {
  required String title,
  required String initialText,
  int maxLength = 2000,
  int maxLines = 6,
}) {
  final controller = TextEditingController(text: initialText);
  final cs = Theme.of(context).colorScheme;

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      title: Text(title, style: TextStyle(color: cs.onSurface)),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: maxLength,
        maxLines: maxLines,
        minLines: 1,
        style: TextStyle(color: cs.onSurface),
        decoration: InputDecoration(
          filled: true,
          fillColor: cs.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancelar', style: TextStyle(color: Theme.of(ctx).hintColor)),
        ),
        ElevatedButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isEmpty || text == initialText.trim()) {
              Navigator.of(ctx).pop();
              return;
            }
            Navigator.of(ctx).pop(text);
          },
          style: ElevatedButton.styleFrom(backgroundColor: cs.primary),
          child: const Text('Guardar', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
