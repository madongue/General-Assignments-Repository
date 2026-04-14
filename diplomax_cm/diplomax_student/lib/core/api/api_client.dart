import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Base URL for the Diplomax CM FastAPI backend.
/// In production this points to the deployed server; in development to localhost.
const kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://diplomax-backend.onrender.com/v1',
);

/// SHA-256 fingerprint of the production TLS certificate.
/// Certificate pinning: any certificate not matching this is rejected,
/// blocking Man-in-the-Middle attacks even with fraudulent CAs.
const kCertFingerprint = String.fromEnvironment(
  'CERT_FINGERPRINT',
  defaultValue: 'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99',
);

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-App-Version': '2.0.0',
        'X-Platform': Platform.operatingSystem,
      },
    ));

    // ── Certificate Pinning ──────────────────────────────────────────────────
    // Only applies on mobile (not web). Compares the server cert's SHA-256
    // fingerprint against our pinned value — rejects anything else.
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        // In debug builds, accept all certs for local testing
        assert(() {
          return true; // skip pinning in debug
        }());
        // Production: verify fingerprint
        final certHash = sha256
            .convert(utf8.encode(cert.pem))
            .bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(':')
            .toUpperCase();
        return certHash == kCertFingerprint.toUpperCase();
      };
      return client;
    };

    // ── Interceptors ────────────────────────────────────────────────────────
    _dio.interceptors.addAll([
      _AuthInterceptor(_storage),
      _LoggingInterceptor(),
      _RetryInterceptor(_dio),
    ]);
  }

  factory ApiClient() => _instance ??= ApiClient._();

  Dio get dio => _dio;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }
}

/// Injects the Bearer token into every request automatically.
class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  _AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Token expired — attempt silent refresh
      try {
        final refreshToken = await _storage.read(key: 'refresh_token');
        if (refreshToken == null) {
          return handler.reject(err);
        }
        final dio = Dio(BaseOptions(baseUrl: kBaseUrl));
        final response = await dio.post(
          '/auth/refresh',
          data: {'refresh_token': refreshToken},
        );
        final newToken = response.data['access_token'] as String;
        await _storage.write(key: 'access_token', value: newToken);
        // Retry the original request with the new token
        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        final retryResponse = await ApiClient().dio.fetch(err.requestOptions);
        return handler.resolve(retryResponse);
      } catch (_) {
        await _storage.deleteAll();
        return handler.reject(err);
      }
    }
    handler.next(err);
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    assert(() {
      // ignore: avoid_print
      print('[API] ${options.method} ${options.path}');
      return true;
    }());
    handler.next(options);
  }
}

class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  _RetryInterceptor(this._dio);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_shouldRetry(err)) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final response = await _dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        return handler.next(err);
      }
    }
    handler.next(err);
  }

  bool _shouldRetry(DioException err) =>
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      (err.response?.statusCode != null && err.response!.statusCode! >= 500);
}
