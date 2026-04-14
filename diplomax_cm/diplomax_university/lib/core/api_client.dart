import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const kUniversityApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://diplomax-backend.onrender.com/v1',
);

class UnivApiClient {
  UnivApiClient._internal() {
    _dio = Dio(BaseOptions(baseUrl: kUniversityApiBaseUrl));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  factory UnivApiClient() => _instance ??= UnivApiClient._internal();

  static UnivApiClient? _instance;

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Dio get dio => _dio;
}

class ApiClient extends UnivApiClient {
  ApiClient() : super._internal();
}
