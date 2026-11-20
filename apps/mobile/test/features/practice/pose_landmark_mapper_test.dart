import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'package:mobile/features/practice/posture/pose_landmark_mapper.dart';

Pose _fullPose({double x = 100, double y = 200, double likelihood = 0.9}) {
  return Pose(
    landmarks: {
      for (final t in PoseLandmarkType.values)
        t: PoseLandmark(type: t, x: x, y: y, z: 10, likelihood: likelihood),
    },
  );
}

void main() {
  group('poseFrameFromMlKit', () {
    test('maps 33 landmarks in BlazePose order, normalised to 0..1', () {
      final frame = poseFrameFromMlKit(
        _fullPose(),
        uprightWidth: 400,
        uprightHeight: 800,
      );

      expect(frame, isNotNull);
      expect(frame!.poseLandmarks, hasLength(kPoseLandmarkCount));
      expect(frame.poseLandmarks.first.x, 0.25);
      expect(frame.poseLandmarks.first.y, 0.25);
      expect(frame.poseLandmarks.first.visibility, 0.9);
      expect(frame.leftHandLandmarks, isNull);
    });

    test('keeps landmark index = PoseLandmarkType.index', () {
      final pose = Pose(
        landmarks: {
          for (final t in PoseLandmarkType.values)
            t: PoseLandmark(
              type: t,
              x: t.index.toDouble(),
              y: 0,
              z: 0,
              likelihood: 1,
            ),
        },
      );
      final frame = poseFrameFromMlKit(
        pose,
        uprightWidth: 100,
        uprightHeight: 100,
      )!;

      final leftShoulder =
          frame.poseLandmarks[PoseLandmarkType.leftShoulder.index];
      expect(leftShoulder.x, PoseLandmarkType.leftShoulder.index / 100);
    });

    test('returns null for an incomplete pose', () {
      final partial = Pose(
        landmarks: {
          PoseLandmarkType.nose: PoseLandmark(
            type: PoseLandmarkType.nose,
            x: 1,
            y: 1,
            z: 0,
            likelihood: 1,
          ),
        },
      );
      expect(
        poseFrameFromMlKit(partial, uprightWidth: 10, uprightHeight: 10),
        isNull,
      );
    });

    test('returns null for invalid image dimensions', () {
      expect(
        poseFrameFromMlKit(_fullPose(), uprightWidth: 0, uprightHeight: 10),
        isNull,
      );
    });

    test('clamps likelihood into 0..1', () {
      final frame = poseFrameFromMlKit(
        _fullPose(likelihood: 1.7),
        uprightWidth: 10,
        uprightHeight: 10,
      )!;
      expect(frame.poseLandmarks.every((l) => l.visibility == 1.0), isTrue);
    });
  });

  group('inputRotationDegrees', () {
    test('iOS uses the sensor orientation directly', () {
      expect(
        inputRotationDegrees(
          sensorOrientation: 270,
          deviceOrientationDegrees: 90,
          isFrontCamera: true,
          isAndroid: false,
        ),
        270,
      );
    });

    test('Android front camera adds the device rotation', () {
      expect(
        inputRotationDegrees(
          sensorOrientation: 270,
          deviceOrientationDegrees: 0,
          isFrontCamera: true,
          isAndroid: true,
        ),
        270,
      );
      expect(
        inputRotationDegrees(
          sensorOrientation: 270,
          deviceOrientationDegrees: 90,
          isFrontCamera: true,
          isAndroid: true,
        ),
        0,
      );
    });

    test('Android back camera subtracts the device rotation', () {
      expect(
        inputRotationDegrees(
          sensorOrientation: 90,
          deviceOrientationDegrees: 90,
          isFrontCamera: false,
          isAndroid: true,
        ),
        0,
      );
    });

    test('rotationSwapsAxes only for 90 and 270', () {
      expect(rotationSwapsAxes(90), isTrue);
      expect(rotationSwapsAxes(270), isTrue);
      expect(rotationSwapsAxes(0), isFalse);
      expect(rotationSwapsAxes(180), isFalse);
    });
  });
}
