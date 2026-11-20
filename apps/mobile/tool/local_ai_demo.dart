// Smoke-test harness for the on-device AI features (pose + SLM tutor).
// Run: flutter run -t tool/local_ai_demo.dart
import 'package:flutter/material.dart';

import 'package:mobile/core/audio/instrument.dart';
import 'package:mobile/core/tutor/tutor_prompt_builder.dart';
import 'package:mobile/features/practice/posture/presentation/screens/posture_camera_view.dart';
import 'package:mobile/features/tutor/presentation/widgets/local_tutor_section.dart';

void main() => runApp(const _Demo());

class _Demo extends StatelessWidget {
  const _Demo();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Local AI demo')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  key: const Key('open_pose'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PostureCameraView(),
                    ),
                  ),
                  child: const Text('Pose'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('open_tutor'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Tutor')),
                        body: const SingleChildScrollView(
                          padding: EdgeInsets.all(16),
                          child: LocalTutorSection(
                            summary: PracticeSummary(
                              score: 72,
                              correctNotes: 7,
                              totalNotes: 10,
                              wrongNotes: 2,
                              missedNotes: 1,
                            ),
                            instrument: InstrumentType.quena,
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Tutor'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
