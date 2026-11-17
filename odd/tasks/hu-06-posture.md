# Feature: HU-06 Detección Postural, Verticalidad y Alineación Anatómica con MediaPipe Pose

Parent Issue: #24 | Milestone: Sprint 2 | Story Points: 8 SP
Architecture: Mobile (Flutter 3.x)

## Specs

S1: "Procesar landmarks de hombros (11, 12), codos (13, 14), muñecas (15, 16) y nariz (0) de MediaPipe Pose para calcular ángulos de desviación frente a la postura ergonómica estándar de viento andino. Inferencia 100% on-device: ningún fotograma crudo sale del dispositivo."
S2: "Clase: PostureAnalyzer, Método: PostureMetrics analyzeKeypoints(List<PoseLandmark> landmarks), Retorno: PostureMetrics(double shoulderTiltDegrees, double elbowAngleDegrees, bool headAligned)."
S3: "Manejo de Errores: rostro u hombros no visibles (confianza < 0.5 o landmarks insuficientes) → PostureMetrics con PostureWarning.userOutOfFrame, sin lanzar excepción ni bloquear la sesión de audio."
S4: "Servicio: MediaPipePoseService implements PoseFrameSource. Ingesta de CameraImage de la cámara frontal e inferencia MediaPipe Pose/Hands en un isolate dedicado, emitiendo un PoseFrame por fotograma (objetivo ≥24 FPS). El binding nativo queda tras la interfaz PoseFrameSource; mientras no esté enlazado, start() falla de forma honesta sin simular tracking."
S5: "PostureBloc (CameraFrame -> AlignmentEvaluated): consume PoseFrameSource y emite PostureAlignmentEvaluated con la puntuación 0-100 (posture_score_percentage) y alertas ergonómicas; conteo determinista de fotogramas."
S6: "Widget: PostureIndicatorWidget. Visor minimalista en el borde de la pantalla que cambia sutilmente de color según la estabilidad postural, evitando saturación cognitiva, consumiendo tokens de apps/mobile/DESIGN.md (AppTheme)."
S7: "Semántica de colores (tokens DESIGN.md): Alineado #10B981 (AppTheme.success), Alerta menor #F97316 (AppTheme.orange), Corrección crítica #EF4444 (AppTheme.error); neutro al congelar."
S8: "Manejo de Errores (visor): si la cámara se desconecta o la app pasa a segundo plano (isActive = false) o el usuario sale de encuadre (isTracking = false), congelar el indicador en estado inactive sin crashear."

## Tasks

- [x] T1 (Specs: S1, S2, S3, S4, S5) [inline]: Implementar PostureAnalyzer (estimación de ángulos y PostureMetrics/PostureWarning), MediaPipePoseService tras PoseFrameSource, y conectar el default del PostureBloc; tests unitarios en posture_analyzer_test.dart (hombros desnivelados > 15°, cabeza inclinada, userOutOfFrame). (Issue #25 - SUB-06-A)
- [x] T2 (Specs: S6, S7, S8) [inline]: Implementar PostureIndicatorWidget consumiendo tokens de DESIGN.md, integrarlo como overlay en PostureCameraView y tests de render condicional por estado del BLoC y congelado sin crash en posture_indicator_widget_test.dart. (Issue #26 - SUB-06-B)

## Log

L1: "corrige mi pr Implementa las subissues de la issue #24 (HU-06), realizalo con ODD, en un propio git worktree. @[AGENTS.md]"
L2: "Trabajo realizado en worktree dedicado (rama hu06-subissues sobre feat/hu-06-postura-mediapipe, PR #85). Reutiliza el motor puro existente (MediaPipePosturePipeline/PostureScorer) sin duplicar. Verificación: flutter analyze sin issues, dart format limpio y flutter test en verde (suite móvil completa, incluidas las pruebas nuevas de PostureAnalyzer y PostureIndicatorWidget)."
