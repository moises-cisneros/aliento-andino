import 'package:flutter/material.dart';

import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/tutor/local_tutor_service.dart';
import 'package:mobile/core/tutor/tutor_prompt_builder.dart';
import 'package:mobile/features/tutor/presentation/widgets/tutor_feedback_card.dart';

/// On-device tutor block for the practice result screen.
///
/// Shows the pedagogical advice generated locally. While the SLM has not been
/// downloaded it shows the deterministic rule-based advice and offers an
/// explicit, opt-in download (~520 MB); after that, advice comes from the
/// model with no network.
class LocalTutorSection extends StatefulWidget {
  final PracticeSummary summary;
  final InstrumentType instrument;
  final LocalTutorService? service;

  const LocalTutorSection({
    super.key,
    required this.summary,
    required this.instrument,
    this.service,
  });

  @override
  State<LocalTutorSection> createState() => _LocalTutorSectionState();
}

class _LocalTutorSectionState extends State<LocalTutorSection> {
  late final LocalTutorService _service =
      widget.service ?? LocalTutorService.instance;

  String? _feedback;
  bool _loading = true;
  bool _modelInstalled = false;
  int? _downloadPercent;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    final installed = await _service.isModelInstalled();
    final text = await _service.generateFeedback(
      widget.summary,
      widget.instrument,
    );
    if (!mounted) return;
    setState(() {
      _modelInstalled = installed;
      _feedback = text;
      _loading = false;
    });
  }

  Future<void> _download() async {
    setState(() {
      _downloadPercent = 0;
      _downloadError = null;
    });
    try {
      await _service.installModel(
        onProgress: (p) {
          if (mounted) setState(() => _downloadPercent = p);
        },
      );
      if (!mounted) return;
      setState(() => _downloadPercent = null);
      await _generate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadPercent = null;
        _downloadError = 'No se pudo descargar el modelo. Revisa tu conexión.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TutorFeedbackCard(
          feedback: _feedback,
          instrument: widget.instrument,
          isLoading: _loading,
        ),
        if (!_loading && !_modelInstalled) ...[
          const SizedBox(height: 8),
          if (_downloadPercent != null) ...[
            LinearProgressIndicator(
              key: const Key('local_tutor_progress'),
              value: _downloadPercent == 0 ? null : _downloadPercent! / 100,
            ),
            const SizedBox(height: 4),
            Text(
              'Descargando tutor IA… $_downloadPercent%',
              style: theme.textTheme.bodySmall,
            ),
          ] else
            TextButton.icon(
              key: const Key('local_tutor_download'),
              onPressed: _download,
              icon: const Icon(Icons.download_for_offline_outlined),
              label: const Text(
                'Activar tutor IA sin conexión (≈520 MB, usa Wi-Fi)',
              ),
            ),
          if (_downloadError != null)
            Text(
              _downloadError!,
              key: const Key('local_tutor_error'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ],
    );
  }
}
