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

  String _parseErrorMessage(http.Response response, String fallback) {
    try {
      final error = json.decode(response.body);
      if (error is Map && error.containsKey('detail')) {
        return error['detail'].toString();
      }
    } catch (_) {
      // Body is not JSON (e.g. plain text 500 error from backend)
    }

    if (response.statusCode >= 500) {
      return 'Server error (${response.statusCode}): Backend database or server is unavailable. Please verify PostgreSQL is running and check server logs.';
    }
    if (response.body.isNotEmpty && response.body.length < 200) {
      return response.body;
    }
    return fallback;
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
        if (token != null) {
          await _storage.write(key: 'auth_token', value: token.toString());
        }
        return data as Map<String, dynamic>;
      } else {
        final errorMsg = _parseErrorMessage(response, 'Invalid email or password');
        throw ApiException(
          response.statusCode == 401 ? ApiErrorType.unauthorized : ApiErrorType.serverError,
          errorMsg,
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
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorMsg = _parseErrorMessage(response, 'Registration failed');
        throw ApiException(
          response.statusCode == 400 ? ApiErrorType.validationError : ApiErrorType.serverError,
          errorMsg,
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
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
