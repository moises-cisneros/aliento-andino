import 'package:dio/dio.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/network/api_client.dart';
import '../offline/offline_faq_assistant.dart';

/// Un mensaje de la conversación con el tutor.
class TutorMessage {
  final String role; // 'user' | 'model'
  final String text;
  const TutorMessage({required this.role, required this.text});

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

/// Una acción de UI que el cliente debe ejecutar (navegar, resaltar, etc.).
class TutorAction {
  final String tool;
  final Map<String, dynamic> args;
  const TutorAction({required this.tool, required this.args});

  factory TutorAction.fromJson(Map<String, dynamic> json) => TutorAction(
        tool: (json['tool'] as String?) ?? '',
        args: (json['args'] as Map<String, dynamic>?) ?? const {},
      );
}

/// Respuesta del agente: texto + acciones.
class TutorReply {
  final String reply;
  final List<TutorAction> actions;
  const TutorReply({required this.reply, required this.actions});

  factory TutorReply.fromJson(Map<String, dynamic> json) => TutorReply(
        reply: (json['reply'] as String?) ?? '',
        actions: ((json['actions'] as List<dynamic>?) ?? const [])
            .map((e) => TutorAction.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Repositorio del agente tutor de IA.
///
/// Arquitectura por capas (router): con internet usa **Gemini/Vertex** (la
/// nube, para lo avanzado); sin internet —o si la nube falla— responde con el
/// **asistente FAQ offline** ([OfflineFaqAssistant]). Así Vivi *siempre*
/// responde algo y da lo mejor cuando hay conexión.
class TutorRepository {
  final ApiClient _apiClient;
  final ConnectivityService? _connectivity;
  final OfflineFaqAssistant? _offline;

  /// Conversación persistente con Vivi durante la sesión de la app: sobrevive
  /// al cierre del chat para que el usuario pueda retomarla.
  final List<TutorMessage> conversation = [];

  TutorRepository({
    required ApiClient apiClient,
    ConnectivityService? connectivity,
    OfflineFaqAssistant? offlineAssistant,
  })  : _apiClient = apiClient,
        _connectivity = connectivity,
        _offline = offlineAssistant;

  void clearConversation() => conversation.clear();

  /// Punto de entrada: enruta entre la nube (Gemini) y el FAQ offline.
  Future<TutorReply> chat(
    String message,
    List<TutorMessage> history, {
    String? currentRoute,
  }) async {
    final online = await _isOnline();
    if (online) {
      try {
        return await _chatRemote(message, history, currentRoute: currentRoute);
      } catch (_) {
        // La nube falló a mitad (timeout / red): intentamos el FAQ local.
        final local = await _offline?.bestMatch(message);
        if (local != null && local.score >= OfflineFaqAssistant.matchThreshold) {
          return _replyFromFaq(local);
        }
        rethrow;
      }
    }

    // Sin conexión: responde el cerebro offline.
    final local = await _offline?.bestMatch(message);
    if (local != null && local.score >= OfflineFaqAssistant.matchThreshold) {
      return _replyFromFaq(local);
    }
    return const TutorReply(
      reply: 'Estás sin conexión 📴. Puedo ayudarte con dudas básicas de la app '
          '(guardar lecciones, rankings, progreso, modo offline, perfil…). '
          'Para preguntas más complejas, volvé a intentar cuando tengas internet.',
      actions: [],
    );
  }

  Future<bool> _isOnline() async {
    final conn = _connectivity;
    if (conn == null) return true;
    try {
      return await conn.isOnline;
    } catch (_) {
      return true; // ante la duda, intentamos la nube
    }
  }

  TutorReply _replyFromFaq(FaqMatch m) => TutorReply(
        reply: m.answer,
        actions: m.action == null ? const [] : [m.action!],
      );

  /// Llama al agente Gemini/Vertex en el backend (capa avanzada, online).
  Future<TutorReply> _chatRemote(
    String message,
    List<TutorMessage> history, {
    String? currentRoute,
  }) async {
    final response = await _apiClient.dio.post(
      '/tutor/chat',
      data: {
        'message': message,
        // Solo enviamos los últimos turnos para acotar el contexto.
        'history': history
            .take(10)
            .map((m) => m.toJson())
            .toList(growable: false),
        'current_route': ?currentRoute,
      },
      // El agente encadena varias llamadas a Gemini (razonar + acciones),
      // así que damos un timeout más amplio que el global (15s).
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );
    return TutorReply.fromJson(response.data as Map<String, dynamic>);
  }
}
