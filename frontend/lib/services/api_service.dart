import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/app_config.dart';
import 'api_exceptions.dart';

class ApiService {
  final String baseUrl;
  final http.Client httpClient;
  final FlutterSecureStorage _storage;
  final AppConfig _config;

  ApiService({
    String? baseUrl,
    http.Client? httpClient,
    FlutterSecureStorage? storage,
    AppConfig? config,
  })  : baseUrl = baseUrl ?? getAppConfig().apiBaseUrl,
        httpClient = httpClient ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage(),
        _config = config ?? getAppConfig() {
    if (kDebugMode) {
      print('✅ ApiService initialized with baseUrl: $baseUrl');
    }
  }

  /// Get stored authentication token
  Future<String?> _getAuthToken() async {
    try {
      return await _storage.read(key: 'auth_token');
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to read auth token: $e');
      }
      return null;
    }
  }

  /// Save authentication token
  Future<void> saveAuthToken(String token) async {
    try {
      await _storage.write(key: 'auth_token', value: token);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to save auth token: $e');
      }
    }
  }

  /// Clear authentication token
  Future<void> clearAuthToken() async {
    try {
      await _storage.delete(key: 'auth_token');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to clear auth token: $e');
      }
    }
  }

  /// Validate file before upload
  Future<void> _validateFile(File file) async {
    if (!await file.exists()) {
      throw ApiException(
        ApiErrorType.validationError,
        'Image file not found at path: ${file.path}',
      );
    }

    final fileSize = await file.length();
    const maxSize = 5 * 1024 * 1024; // 5 MB

    if (fileSize > maxSize) {
      throw ApiException(
        ApiErrorType.validationError,
        'File too large (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB). Maximum size is 5 MB.',
      );
    }

    if (fileSize == 0) {
      throw ApiException(
        ApiErrorType.validationError,
        'Image file is empty.',
      );
    }
  }

  /// Validate coordinates
  void _validateCoordinates(double latitude, double longitude) {
    if (latitude < -90 || latitude > 90) {
      throw ApiException(
        ApiErrorType.validationError,
        'Invalid latitude. Must be between -90 and 90.',
      );
    }

    if (longitude < -180 || longitude > 180) {
      throw ApiException(
        ApiErrorType.validationError,
        'Invalid longitude. Must be between -180 and 180.',
      );
    }
  }

  /// Validate description
  void _validateDescription(String description) {
    if (description.length > 1000) {
      throw ApiException(
        ApiErrorType.validationError,
        'Description too long. Maximum 1000 characters.',
      );
    }
  }

  /// Submit incident with retry logic
  Future<Map<String, dynamic>> submitIncident({
    required String imagePath,
    required double latitude,
    required double longitude,
    required String description,
  }) async {
    return _retryRequest(
      () => _submitIncidentOnce(
        imagePath: imagePath,
        latitude: latitude,
        longitude: longitude,
        description: description,
      ),
      maxRetries: _config.maxRetries,
    );
  }

  /// Internal method to submit incident (no retries)
  Future<Map<String, dynamic>> _submitIncidentOnce({
    required String imagePath,
    required double latitude,
    required double longitude,
    required String description,
  }) async {
    try {
      // 1. Validate input
      _validateCoordinates(latitude, longitude);
      _validateDescription(description);

      final file = File(imagePath);
      await _validateFile(file);

      // 2. Get extension and MIME type
      final fileExtension = file.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(fileExtension)) {
        throw ApiException(
          ApiErrorType.validationError,
          'Invalid file format. Supported: JPEG, PNG, WebP',
        );
      }

      final mimeSubtype = fileExtension == 'png' ? 'png' : 'jpeg';

      // 3. Build request
      final uri = Uri.parse('$baseUrl/incidents/report');
      final request = http.MultipartRequest('POST', uri);

      // 4. Add authentication if available
      final token = await _getAuthToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // 5. Add form fields
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      request.fields['description'] = description.trim();

      // 6. Add image file
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType('image', mimeSubtype),
      );
      request.files.add(multipartFile);

      // 7. Send request with timeout
      if (kDebugMode) {
        print('📤 Uploading incident to: $uri');
      }

      final streamedResponse = await httpClient.send(request).timeout(
        Duration(seconds: _config.requestTimeoutSeconds),
        onTimeout: () {
          throw ApiException(
            ApiErrorType.timeout,
            'Request timed out after ${_config.requestTimeoutSeconds} seconds',
          );
        },
      );

      // 8. Get response
      final response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        print('📥 Response: ${response.statusCode}');
      }

      // 9. Handle response
      return _handleResponse(response);
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('❌ TimeoutException: $e');
      }
      throw ApiException(
        ApiErrorType.timeout,
        'Request timed out',
        originalError: e,
      );
    } on SocketException catch (e) {
      if (kDebugMode) {
        print('❌ SocketException: $e');
      }
      throw ApiException(
        ApiErrorType.networkError,
        'Network error: ${e.message}',
        originalError: e,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected error: $e');
      }
      throw ApiException(
        ApiErrorType.unknown,
        'Unexpected error: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Handle API response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 201) {
      try {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (kDebugMode) {
          print('✅ Incident submitted successfully');
        }
        return body;
      } catch (e) {
        throw ApiException(
          ApiErrorType.unknown,
          'Failed to parse response',
          originalError: e,
        );
      }
    }

    // Parse error response
    try {
      final errorBody = json.decode(response.body);
      final detail = errorBody['detail'] ?? 'Unknown error';

      switch (response.statusCode) {
        case 400:
          throw ApiException(
            ApiErrorType.validationError,
            detail,
            statusCode: response.statusCode,
          );
        case 401:
          throw ApiException(
            ApiErrorType.unauthorized,
            detail,
            statusCode: response.statusCode,
          );
        case 403:
          throw ApiException(
            ApiErrorType.forbidden,
            detail,
            statusCode: response.statusCode,
          );
        case 413:
          throw ApiException(
            ApiErrorType.validationError,
            'File too large. Maximum 5MB.',
            statusCode: response.statusCode,
          );
        case 415:
          throw ApiException(
            ApiErrorType.validationError,
            'Unsupported file format. Use JPEG or PNG.',
            statusCode: response.statusCode,
          );
        case 503:
          throw ApiException(
            ApiErrorType.serverError,
            'Server is temporarily unavailable. Please try again later.',
            statusCode: response.statusCode,
          );
        default:
          throw ApiException(
            ApiErrorType.serverError,
            'Server error: $detail',
            statusCode: response.statusCode,
          );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        ApiErrorType.unknown,
        'Error: ${response.statusCode} - ${response.reasonPhrase}',
        statusCode: response.statusCode,
        originalError: e,
      );
    }
  }

  /// Retry logic for failed requests
  Future<T> _retryRequest<T>(
    Future<T> Function() request, {
    int maxRetries = 3,
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await request();
      } on ApiException catch (e) {
        // Don't retry on validation or auth errors
        if (e.type == ApiErrorType.validationError ||
            e.type == ApiErrorType.unauthorized ||
            e.type == ApiErrorType.forbidden) {
          rethrow;
        }

        if (i == maxRetries - 1) {
          rethrow;
        }

        // Exponential backoff
        final delay = Duration(seconds: 2 * (i + 1));
        if (kDebugMode) {
          print(
              '⚠️ Retry attempt ${i + 1}/$maxRetries after ${delay.inSeconds}s');
        }
        await Future.delayed(delay);
      }
    }

    throw ApiException(
      ApiErrorType.unknown,
      'Failed after $maxRetries retries',
    );
  }
}

/// Global API service instance
final apiService = ApiService();
