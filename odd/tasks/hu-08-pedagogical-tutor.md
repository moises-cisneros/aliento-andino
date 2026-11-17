# Feature: HU-08 Agente Tutor Pedagógico con SLM Local On-Device

Issues: #30 (HU-08), #31 (SUB-08-A), #32 (SUB-08-B)
Sprint: 2 | Area: mobile / ml | Worktree: hu-08-pedagogical-tutor

## Specs

- S1: "Descarga inicial y carga en memoria del modelo cuantizado (4-bit INT4) con MediaPipe GenAI Tasks o WebLLM, manteniendo el uso de RAM <= 250MB."
- S2: "Archivos a crear o modificar: apps/mobile/lib/core/tutor/local_slm_engine.dart, apps/ml/server.py"
- S3: "Contratos Técnicos: Clase: LocalSlmEngine, Método: Future<void> initializeModel({required String modelPath}), Método: Future<String> generatePedagogicalFeedback({required String prompt})"
- S4: "Manejo de Errores: Dispositivo con RAM insuficiente (< 2GB libre): Fallback automático al motor de reglas pedagógicas deterministas pregrabadas (RuleBasedTutorFallback)."
- S5: "Pruebas Obligatorias: Unitaria: apps/mobile/test/core/tutor/local_slm_engine_test.dart verificando generación de texto ante prompt sintético. Integración: Fallback a reglas deterministas cuando el runtime de SLM no está disponible. E2E: Medición de tiempo de respuesta garantizando <= 3 segundos."
- S6: "Traducir métricas discretas en un prompt estructurado y mostrar el consejo resultante en la tarjeta del tutor según la guía visual de apps/mobile/DESIGN.md."
- S7: "Archivos a crear o modificar: apps/mobile/lib/features/tutor/presentation/widgets/tutor_feedback_card.dart, apps/mobile/lib/core/tutor/tutor_prompt_builder.dart"
- S8: "Contratos Técnicos: Clase: TutorPromptBuilder, Método: String buildPrompt(PracticeSummary summary, InstrumentType instrument)"
- S9: "Manejo de Errores: Generación de respuesta vacía o timeout: Presentar consejo predeterminado: '¡Buen esfuerzo! Recuerda mantener el flujo de aire constante y los hombros relajados'."
- S10: "Pruebas Obligatorias: Unitaria: apps/mobile/test/core/tutor/tutor_prompt_builder_test.dart validando construcción estricta del prompt. Integración: Test de widget TutorFeedbackCard mostrando texto generado. E2E: Flujo completo post-lección con despliegue de consejo del tutor."
- S11: "El modelo SLM local (Gemma 2 2B / Llama 3.2 1B-3B) procesa el resumen de telemetría sin conexión a internet. Genera recomendaciones en español con lenguaje constructivo y pedagógico andino. El tiempo de generación del consejo no excede los 3 segundos tras finalizar la canción."
- S12: "Pruebas unitarias, de integración y E2E asociadas con cobertura >= 80% (backend) o >= 75% (web/mobile) y suites en verde."
- S13: "Instrumentos no andinos (guitarra, piano); transmisión de audio o video sin procesar a servicios de nube en tiempo de ejecución (la inferencia acústica y postural es 100% on-device)."

## Tasks

- [x] T1: SUB-08-A Configuración de Runtime SLM Local On-Device (S1, S2, S3, S4, S5, S11, S12, S13) | route: inline | commit: feat(mobile): add on-device slm runtime engine with rule-based fallback
- [x] T2: SUB-08-B Síntesis de Telemetría a Prompt Pedagógico y Renderizado (S6, S7, S8, S9, S10, S11, S12, S13) | route: inline | commit: feat(mobile): build pedagogical prompt synthesizer and tutor feedback card

## Log

- L1: "Implementa las subissues de la issue #30 (HU-08), realizalo con ODD, en un propio git worktree."
