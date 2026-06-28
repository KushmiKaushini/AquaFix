import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_exceptions.dart';

class AuthService {
  final http.Client _httpClient;
  final FlutterSecureStorage _storage;
  final AppConfig _config;

  AuthService({
    http.Client? httpClient,
    FlutterSecureStorage? storage,
    AppConfig? config,
  })  : _httpClient = httpClient ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage(),
        _config = config ?? getAppConfig();

  Future<String?> get authToken async {
    return await _storage.read(key: 'auth_token');
  }

  Future<bool> isLoggedIn() async {
    final token = await authToken;
    return token != null && token.isNotEmpty;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('${_config.apiBaseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      ).timeout(Duration(seconds: _config.requestTimeoutSeconds));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['access_token'];
        await _storage.write(key: 'auth_token', value: token);
        return data;
      } else {
        final error = json.decode(response.body);
        throw ApiException(
          ApiErrorType.unauthorized,
          error['detail'] ?? 'Login failed',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorType.networkError,
        'Network error: ${e.toString()}',
        originalError: e,
      );
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String role = 'citizen',
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('${_config.apiBaseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'full_name': fullName,
          'role': role,
        }),
      ).timeout(Duration(seconds: _config.requestTimeoutSeconds));

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw ApiException(
          ApiErrorType.validationError,
          error['detail'] ?? 'Registration failed',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorType.networkError,
        'Network error: ${e.toString()}',
        originalError: e,
      );
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final token = await authToken;
      if (token == null) return null;

      final response = await _httpClient.get(
        Uri.parse('${_config.apiBaseUrl}/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: _config.requestTimeoutSeconds));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
