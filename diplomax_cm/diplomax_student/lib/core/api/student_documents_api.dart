import 'package:dio/dio.dart';

import 'api_client.dart';

class StudentDocumentsApi {
  StudentDocumentsApi._();

  static final StudentDocumentsApi instance = StudentDocumentsApi._();

  final ApiClient _client = ApiClient();

  Future<List<Map<String, dynamic>>> fetchDocuments({
    String? query,
    String? type,
    String? year,
    String? mention,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _client.dio.get(
      '/documents/search',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
        if (year != null && year.trim().isNotEmpty) 'year': year.trim(),
        if (mention != null && mention.trim().isNotEmpty)
          'mention': mention.trim(),
        'page': page,
        'page_size': pageSize,
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final items = data['items'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return const [];
  }

  Future<Map<String, dynamic>?> fetchDocument(String documentId) async {
    try {
      final response = await _client.dio.get('/documents/$documentId');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
    } on DioException {
      rethrow;
    }
    return null;
  }
}
