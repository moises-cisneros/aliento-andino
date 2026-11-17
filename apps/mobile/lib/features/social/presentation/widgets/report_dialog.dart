import 'package:flutter/material.dart';

/// Diálogo para reportar contenido.
class ReportDialog extends StatefulWidget {
  final String? postId;
  final String? commentId;
  final String? reportedUserId;
  final void Function(String reason, String? description) onSubmit;

  const ReportDialog({
    super.key,
    this.postId,
    this.commentId,
    this.reportedUserId,
    required this.onSubmit,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _selectedReason;
  final _descriptionController = TextEditingController();

  static const _reasons = [
    'spam',
    'inappropriate',
    'harassment',
    'hate_speech',
    'other',
  ];

  static const _reasonLabels = {
    'spam': 'Spam',
    'inappropriate': 'Contenido inapropiado',
    'harassment': 'Acoso',
    'hate_speech': 'Discurso de odio',
    'other': 'Otro',
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      title: Text(
        'Reportar',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecciona un motivo:',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _selectedReason ?? '',
              onChanged: (v) => setState(() => _selectedReason = v),
              child: Column(
                children: _reasons
                    .map(
                      (r) => RadioListTile<String>(
                        title: Text(
                          _reasonLabels[r]!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                        value: r,
                        activeColor: Theme.of(context).colorScheme.primary,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _selectedReason == 'other'
                    ? 'Describe el motivo...'
                    : 'Descripción adicional (opcional)',
                hintStyle: TextStyle(color: Theme.of(context).hintColor),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ),
        ElevatedButton(
          onPressed: _selectedReason != null
              ? () {
                  widget.onSubmit(
                    _selectedReason!,
                    _descriptionController.text.isEmpty
                        ? null
                        : _descriptionController.text,
                  );
                  Navigator.of(context).pop();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(
            'Reportar',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}
