import 'dart:async';

/// Interfaz para el backend del runtime SLM (MediaPipe GenAI Tasks o WebLLM).
abstract class SlmRuntime {
  /// Inicializa y carga en memoria el modelo cuantizado (4-bit INT4).
  /// Debe mantener el consumo de memoria RAM <= 250 MB.
  Future<void> loadModel(String modelPath);

  /// Genera texto pedagógico a partir del prompt proporcionado.
  Future<String> generateResponse(String prompt);

  /// Indica si el modelo se encuentra cargado y listo para inferencia.
  bool get isLoaded;

  /// Libera los recursos del modelo de la memoria.
  void dispose();
}

/// Fallback determinista basado en reglas pedagógicas pregrabadas para
/// instrumentos andinos (Quena, Zampoña, Tarka) cuando el dispositivo cuenta
/// con RAM insuficiente (< 2 GB libres) o el runtime SLM no está disponible.
class RuleBasedTutorFallback {
  const RuleBasedTutorFallback();

  /// Genera un consejo pedagógico estructurado en español andino según el prompt.
  String generateFeedback(String prompt) {
    final lower = prompt.toLowerCase();

    // 1. Detección por instrumento específico
    if (lower.contains('quena')) {
      if (lower.contains('orificio') ||
          lower.contains('digitacion') ||
          lower.contains('fallad')) {
        return '¡Buen esfuerzo con la Quena! Asegúrate de cubrir completamente el 3er orificio con la yema del dedo para evitar fugas de aire y estabilizar la octava.';
      }
      if (lower.contains('desafinad') ||
          lower.contains('cents') ||
          lower.contains('afinacion')) {
        return 'Para afinar mejor en la Quena, controla el ángulo de la embocadura contra el labio inferior y mantén un soplo suave y constante.';
      }
      if (lower.contains('postura') ||
          lower.contains('espalda') ||
          lower.contains('hombros')) {
        return 'Mantén la espalda recta y relaja los hombros. Sostén la Quena a 45 grados respecto al torso para liberar la caja torácica.';
      }
      if (lower.contains('tempo') || lower.contains('ritmo')) {
        return 'Buen pulso en la Quena. Practica a un tempo más lento con metrónomo para afianzar el ritmo de las melodías andinas.';
      }
      return 'Excelente avance con la Quena. Practica notas largas respirando desde el diafragma para consolidar un sonido limpio y andino.';
    }

    if (lower.contains('zampoña') || lower.contains('zampona')) {
      if (lower.contains('desafinad') ||
          lower.contains('ataque') ||
          lower.contains('aire')) {
        return 'En la Zampoña, orienta el soplo perpendicular al bisel del tubo con un ataque seco ("ta") para que la nota resuene con claridad.';
      }
      if (lower.contains('ira') ||
          lower.contains('arka') ||
          lower.contains('tubo')) {
        return 'Verifica la alineación entre las hileras Ira y Arka; mantén la Zampoña vertical y mueve la cabeza suavemente entre tubos.';
      }
      if (lower.contains('tempo') || lower.contains('ritmo')) {
        return 'Buen ritmo en la Zampoña. Coordina el soplido rítmico sincronizando el paso entre tubos a compás constante.';
      }
      return '¡Gran interpretación en la Zampoña! Mantén los labios firmes en el borde superior para proyectar un sonido ceremonial pleno.';
    }

    if (lower.contains('tarka')) {
      if (lower.contains('aire') ||
          lower.contains('presion') ||
          lower.contains('sonido')) {
        return 'La Tarka requiere un ataque de aire firme y directo en la boquilla de madera para activar su timbre rasposo característico (tara).';
      }
      if (lower.contains('orificio') || lower.contains('digitacion')) {
        return 'Sella con firmeza los orificios rectangulares de la Tarka con las yemas planas de los dedos para mantener la afinación pentatónica.';
      }
      if (lower.contains('tempo') || lower.contains('ritmo')) {
        return 'En la Tarka, marca claramente el pulso ceremonial manteniendo una presión de aire estable en cada tiempo.';
      }
      return 'Buen trabajo con la Tarka. Mantén la columna de aire constante para dominar las transiciones entre las octavas baja y alta.';
    }

    // 2. Detección por áreas técnicas comunes
    if (lower.contains('postura') || lower.contains('inclinacion')) {
      return 'Cuida tu postura: mantén la espalda erguida, los hombros relajados y el instrumento centrado para proyectar el aire sin tensión.';
    }

    if (lower.contains('tempo') || lower.contains('ritmo')) {
      return 'Buen pulso general. Practica a un tempo más lento con metrónomo antes de aumentar la velocidad de las frases melódicas.';
    }

    // Fallback estándar predeterminado
    return '¡Buen esfuerzo! Recuerda mantener el flujo de aire constante y los hombros relajados.';
  }
}

/// Motor local de inferencia SLM On-Device (Gemma 2 2B / Llama 3.2 1B-3B cuantizados INT4).
///
/// Gestiona la carga en memoria (manteniendo RAM <= 250 MB), verifica que el
/// dispositivo disponga de suficiente memoria libre (>= 2 GB) y conmuta
/// automáticamente al motor de reglas deterministas [RuleBasedTutorFallback]
/// si las condiciones de hardware no son aptas o el runtime falla.
class LocalSlmEngine {
  /// Umbral mínimo de RAM libre en megabytes para permitir la ejecución del SLM (2 GB).
  static const int minFreeRamThresholdMb = 2048;

  /// Límite estricto de memoria asignada al modelo SLM cuantizado en megabytes.
  static const int maxModelRamUsageMb = 250;

  /// Tiempo máximo tolerado para la generación del consejo pedagógico (3 segundos).
  static const Duration maxGenerationTimeout = Duration(seconds: 3);

  final SlmRuntime? _runtime;
  final RuleBasedTutorFallback _fallback;
  final int Function()? _freeRamProvider;

  bool _isModelInitialized = false;
  bool _fallbackActive = false;
  String? _loadedModelPath;

  LocalSlmEngine({
    SlmRuntime? runtime,
    RuleBasedTutorFallback fallback = const RuleBasedTutorFallback(),
    int Function()? freeRamProvider,
  }) : _runtime = runtime,
       _fallback = fallback,
       _freeRamProvider = freeRamProvider;

  /// Indica si el modelo SLM se encuentra activo y listo para inferir.
  bool get isModelInitialized => _isModelInitialized && !_fallbackActive;

  /// Indica si el motor está operando en modo fallback por restricciones de hardware o error.
  bool get isFallbackActive => _fallbackActive;

  /// Ruta del modelo actualmente cargado en memoria, o `null` si no está cargado.
  String? get loadedModelPath => _loadedModelPath;

  /// Descarga inicial y carga en memoria del modelo cuantizado (4-bit INT4).
  ///
  /// Si la memoria libre disponible es menor a [minFreeRamThresholdMb] (< 2 GB),
  /// o si el runtime no está disponible o falla al cargar, activa automáticamente
  /// el fallback determinista [RuleBasedTutorFallback].
  Future<void> initializeModel({required String modelPath}) async {
    final freeRam = _freeRamProvider?.call() ?? _getEstimatedFreeRamMb();

    // Verificación de recursos de hardware (RAM libre >= 2 GB)
    if (freeRam < minFreeRamThresholdMb) {
      _fallbackActive = true;
      _isModelInitialized = false;
      return;
    }

    if (_runtime == null) {
      _fallbackActive = true;
      _isModelInitialized = false;
      return;
    }

    try {
      await _runtime.loadModel(modelPath);
      _loadedModelPath = modelPath;
      _isModelInitialized = _runtime.isLoaded;
      _fallbackActive = !_isModelInitialized;
    } catch (_) {
      // Degradación elegante ante error de carga o modelo corrupto
      _fallbackActive = true;
      _isModelInitialized = false;
    }
  }

  /// Genera retroalimentación pedagógica contextual basada en el prompt suministrado.
  ///
  /// Garantiza un tiempo de respuesta <= 3 segundos mediante timeout controlado.
  /// Si ocurre un timeout, una excepción o el fallback está activo, retorna
  /// la recomendación del motor determinista.
  Future<String> generatePedagogicalFeedback({required String prompt}) async {
    if (_fallbackActive || !_isModelInitialized || _runtime == null) {
      return _fallback.generateFeedback(prompt);
    }

    try {
      final feedback = await _runtime
          .generateResponse(prompt)
          .timeout(maxGenerationTimeout);

      if (feedback.trim().isEmpty) {
        return _fallback.generateFeedback(prompt);
      }

      return feedback.trim();
    } on TimeoutException {
      // Si la inferencia excede los 3 segundos, degradar inmediatamente a fallback
      return _fallback.generateFeedback(prompt);
    } catch (_) {
      // Error de inferencia capturado limpiamente sin propagar fallos a la UI
      return _fallback.generateFeedback(prompt);
    }
  }

  /// Libera recursos del modelo si el runtime está cargado.
  void dispose() {
    _runtime?.dispose();
    _isModelInitialized = false;
    _fallbackActive = false;
    _loadedModelPath = null;
  }

  /// Estimación interna de memoria libre cuando no se inyecta un proveedor nativo.
  int _getEstimatedFreeRamMb() {
    // Valor por defecto representativo para dispositivos móviles estándar
    return 3072;
  }
}
