import '../../../core/network/api_client.dart';
import 'notification_model.dart';

/// Repositorio para notificaciones in-app.
class NotificationRepository {
  final ApiClient _apiClient;

  const NotificationRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  Future<NotificationListResult> list({int limit = 50}) async {
    final response = await _apiClient.dio.get(
      '/notifications',
      queryParameters: {'limit': limit},
    );
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return NotificationListResult(
      items: items,
      total: data['total'] as int? ?? 0,
      unreadCount: data['unread_count'] as int? ?? 0,
    );
  }

  Future<int> unreadCount() async {
    final response = await _apiClient.dio.get('/notifications/unread-count');
    return (response.data['unread_count'] as int?) ?? 0;
  }

  Future<void> markRead(String id) async {
    await _apiClient.dio.post('/notifications/mark-read/$id');
  }

  Future<void> markAllRead() async {
    await _apiClient.dio.post('/notifications/mark-all-read');
  }
}

class NotificationListResult {
  final List<NotificationModel> items;
  final int total;
  final int unreadCount;

  const NotificationListResult({
    required this.items,
    required this.total,
    required this.unreadCount,
  });
}
