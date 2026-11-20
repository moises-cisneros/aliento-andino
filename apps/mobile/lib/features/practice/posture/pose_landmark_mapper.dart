import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'package:mobile/features/practice/posture/pose_frame_source.dart';
import 'package:mobile/features/practice/posture/posture_scorer.dart';

/// Number of BlazePose landmarks emitted by the on-device detector.
const int kPoseLandmarkCount = 33;

/// Converts an ML Kit [Pose] (BlazePose, 33 landmarks, pixel coordinates in the
/// upright image) into a [PoseFrame] with coordinates normalised to 0..1.
///
/// [uprightWidth] and [uprightHeight] are the image dimensions *after* applying
/// the sensor rotation. Returns `null` when the pose is incomplete so callers
/// never feed partial skeletons to the posture pipeline.
PoseFrame? poseFrameFromMlKit(
  Pose pose, {
  required double uprightWidth,
  required double uprightHeight,
}) {
  if (uprightWidth <= 0 || uprightHeight <= 0) return null;
  if (pose.landmarks.length < kPoseLandmarkCount) return null;

  final landmarks = <NormalizedLandmark>[];
  for (final type in PoseLandmarkType.values) {
    final landmark = pose.landmarks[type];
    if (landmark == null) return null;
    landmarks.add(
      NormalizedLandmark(
        x: landmark.x / uprightWidth,
        y: landmark.y / uprightHeight,
        // ML Kit reports z on the same scale as x; normalise it alike.
        z: landmark.z / uprightWidth,
        visibility: landmark.likelihood.clamp(0.0, 1.0).toDouble(),
      ),
    );
  }
  return PoseFrame(poseLandmarks: landmarks);
}

/// Rotation (degrees clockwise) to hand to ML Kit so the frame is upright.
///
/// Mirrors the algorithm recommended by the ML Kit Flutter plugin: iOS reports
/// the sensor orientation directly, while Android compensates for the device
/// orientation and flips the sign for the front camera.
int inputRotationDegrees({
  required int sensorOrientation,
  required int deviceOrientationDegrees,
  required bool isFrontCamera,
  required bool isAndroid,
}) {
  if (!isAndroid) return sensorOrientation % 360;
  if (isFrontCamera) {
    return (sensorOrientation + deviceOrientationDegrees) % 360;
  }
  return (sensorOrientation - deviceOrientationDegrees + 360) % 360;
}

/// Whether the rotated frame swaps width and height (90° / 270°).
bool rotationSwapsAxes(int rotationDegrees) =>
    rotationDegrees == 90 || rotationDegrees == 270;
