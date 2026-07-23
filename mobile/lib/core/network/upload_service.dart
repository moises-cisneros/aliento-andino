import 'package:dio/dio.dart';

import 'api_client.dart';

/// Subir archivos al backend (multipart/form-data → GCS via /api/uploads/media).
class UploadService {
  final ApiClient _apiClient;

  const UploadService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Sube un archivo y devuelve la URL pública.
  ///
  /// [folder] puede ser 'posts', 'avatars' o 'lessons' (lessons solo admin).
  Future<String> uploadFile({
    required String filePath,
    String folder = 'posts',
  }) async {
    final fileName = filePath.split(RegExp(r'[/\\]')).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'folder': folder,
    });

    final response = await _apiClient.dio.post(
      '/uploads/media',
      data: formData,
    );
    return response.data['url'] as String;
  }
}
