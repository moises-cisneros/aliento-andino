import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/tutor/offline/embedder.dart';
import 'package:mobile/features/tutor/offline/lightweight_embedder.dart';
import 'package:mobile/features/tutor/offline/offline_faq_assistant.dart';
import 'package:mobile/features/tutor/offline/tflite_minilm_embedder.dart';

/// Embedder alternativo trivial: existe SOLO para demostrar que el slot
/// [Embedder] es real (el asistente corre con cualquier implementación).
class _FakeEmbedder implements Embedder {
  const _FakeEmbedder();
  @override
  int get dim => 16;
  @override
  List<double> embed(String text) {
    final v = List<double>.filled(16, 0.0);
    for (final c in text.toLowerCase().codeUnits) {
      v[c % 16] += 1.0;
    }
    var n = 0.0;
    for (final x in v) {
      n += x * x;
    }
    n = math.sqrt(n);
    if (n > 0) {
      for (var i = 0; i < 16; i++) {
        v[i] /= n;
      }
    }
    return v;
  }
}

/// Pruebas del **cerebro offline de Vivi** (FAQ semántico sin internet).
/// Corren con `flutter test` (no necesitan dispositivo). Replican el banco de
/// pruebas del prototipo en Python (`ml/faq_semantic/semantic_faq.py`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LightweightEmbedder', () {
    const emb = LightweightEmbedder();

    test('embedding determinista y normalizado L2', () {
      final v1 = emb.embed('hola como guardo una leccion');
      final v2 = emb.embed('hola como guardo una leccion');
      expect(v1.length, LightweightEmbedder.kDim);
      expect(v1, equals(v2)); // determinista
      var norm = 0.0;
      for (final x in v1) {
        norm += x * x;
      }
      expect(norm, closeTo(1.0, 1e-6)); // L2 = 1
      expect(cosineSimilarity(v1, v2), closeTo(1.0, 1e-6));
    });

    test('normalize quita acentos y puntuación', () {
      expect(
        LightweightEmbedder.normalize('¿Cómo guardó la lección?'),
        'como guardo la leccion',
      );
    });
  });

  group('OfflineFaqAssistant (recupera reformulaciones)', () {
    late OfflineFaqAssistant faq;
    setUp(() => faq = OfflineFaqAssistant());

    final cases = <String, String>{
      'se me olvido la clave, no entro': 'recuperar_password',
      'donde miro mi puntaje y mis sesiones': 'progreso',
      'como pongo el tempo mas lento para practicar': 'modo_entrenamiento',
      'quiero guardar esta cancion para despues': 'guardar_leccion',
      'que hago para que la gente me siga': 'seguir_usuarios',
      'en que puesto del ranking voy': 'rankings',
      'se puede practicar sin wifi': 'modo_offline',
      'la app escucha lo que toco y lo reconoce': 'deteccion_acordes',
      'como subo una publicacion a la comunidad': 'crear_publicacion',
    };

    cases.forEach((query, expectedId) {
      test('"$query" -> $expectedId', () async {
        final m = await faq.bestMatch(query);
        expect(m, isNotNull);
        expect(m!.id, expectedId);
        expect(
          m.score,
          greaterThanOrEqualTo(OfflineFaqAssistant.matchThreshold),
        );
      });
    });

    test('una entrada con acción devuelve su TutorAction', () async {
      final m = await faq.bestMatch('donde veo lo que guarde');
      expect(m, isNotNull);
      expect(m!.id, 'guardar_leccion');
      expect(m.action, isNotNull);
      expect(m.action!.tool, 'navigate_to');
    });

    test('pregunta fuera de tema queda por debajo del umbral', () async {
      final m = await faq.bestMatch(
        'cual es la capital de francia y el dolar hoy',
      );
      expect(m, isNotNull);
      expect(m!.score, lessThan(OfflineFaqAssistant.matchThreshold));
    });
  });

  group('Embedder intercambiable (slot del upgrade TFLite)', () {
    test('el OfflineFaqAssistant corre con CUALQUIER Embedder', () async {
      // Inyectamos un embedder totalmente distinto (dim 16) sin tocar nada más:
      // prueba de que el asistente depende solo de la interfaz, no del motor.
      final faq = OfflineFaqAssistant(embedder: const _FakeEmbedder());
      final m = await faq.bestMatch('como guardo una leccion');
      expect(m, isNotNull); // corre end-to-end con otro embedder
      expect(m!.id, isA<String>());
    });

    test('TfliteMiniLmEmbedder YA es un Embedder válido (slot listo)', () {
      const Embedder slot = TfliteMiniLmEmbedder(); // type-checks como Embedder
      expect(slot, isA<Embedder>());
      expect(slot.dim, 384); // all-MiniLM-L6-v2
      // No se ejecuta: embed() lanza hasta enchufar el modelo + tflite_flutter.
      expect(() => slot.embed('hola'), throwsUnimplementedError);
    });

    test('OfflineFaqAssistant acepta el slot TFLite sin cambios de tipo', () {
      // Compila => el slot encaja en el constructor. (No corremos bestMatch
      // porque embed() del skeleton lanza a propósito.)
      final faq = OfflineFaqAssistant(embedder: const TfliteMiniLmEmbedder());
      expect(faq, isA<OfflineFaqAssistant>());
    });
  });
}
