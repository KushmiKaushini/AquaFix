import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'api_exceptions.dart';

class ApiService {
  final String baseUrl;
  final http.Client _httpClient;
  final AuthService _authService;
  final AppConfig _config;

  ApiService({
    String? baseUrl,
    http.Client? httpClient,
    AuthService? authService,
    AppConfig? config,
  })  : baseUrl = baseUrl ?? getAppConfig().apiBaseUrl,
        _httpClient = httpClient ?? http.Client(),
        _authService = authService ?? AuthService(),
        _config = config ?? getAppConfig();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.authToken;
    if (token != null) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }

  /// Submit incident report with image upload
  Future<Map<String, dynamic>> submitIncident({
    required String imagePath,
    required double latitude,
    required double longitude,
    required String description,
  }) async {
    try {
      _validateCoordinates(latitude, longitude);
      _validateDescription(description);

      final file = File(imagePath);
      if (!await file.exists()) {
        throw ApiException(
          ApiErrorType.validationError,
          'Image file not found',
        );
      }

      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw ApiException(
          ApiErrorType.validationError,
          'File too large. Maximum 5MB.',
        );
      }

      final fileExtension = file.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(fileExtension)) {
        throw ApiException(
          ApiErrorType.validationError,
          'Invalid file format. Supported: JPEG, PNG, WebP',
        );
      }

      final uri = Uri.parse('$baseUrl/incidents/report');
      final request = http.MultipartRequest('POST', uri);

      // Add auth headers
      final authHeaders = await _authHeaders();
      request.headers.addAll(authHeaders);

      // Add form fields
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      request.fields['description'] = description.trim();

      // Add image file
      final mimeSubtype = fileExtension == 'png' ? 'png' : 'jpeg';
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType('image', mimeSubtype),
      );
      request.files.add(multipartFile);

      final streamedResponse = await _httpClient.send(request).timeout(
        Duration(seconds: _config.requestTimeoutSeconds),
        onTimeout: () {
          throw ApiException(
            ApiErrorType.timeout,
            'Request timed out after ${_config.requestTimeoutSeconds} seconds',
          );
        },
      );

      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorType.unknown,
        'Unexpected error: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Fetch incidents list with pagination
  Future<Map<String, dynamic>> getIncidents({
    int skip = 0,
    int limit = 20,
    String? statusFilter,
    double? lat,
    double? lon,
    double? radius,
  }) async {
    try {
      final queryParams = <String, String>{
        'skip': skip.toString(),
        'limit': limit.toString(),
      };

      if (statusFilter != null) {
        queryParams['status_filter'] = statusFilter;
      }
      if (lat != null && lon != null && radius != null) {
        queryParams['lat'] = lat.toString();
        queryParams['lon'] = lon.toString();
        queryParams['radius'] = radius.toString();
      }

      final uri = Uri.parse('$baseUrl/incidents/').replace(
        queryParameters: queryParams,
      );

      final authHeaders = await _authHeaders();
      final response = await _httpClient.get(
        uri,
        headers: {..._headers, ...authHeaders},
      ).timeout(Duration(seconds: _config.requestTimeoutSeconds));

      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorType.networkError,
        'Failed to fetch incidents: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Fetch single incident details
  Future<Map<String, dynamic>> getIncident(String incidentId) async {
    try {
      final uri = Uri.parse('$baseUrl/incidents/$incidentId');
      final authHeaders = await _authHeaders();
      final response = await _httpClient.get(
        uri,
        headers: {..._headers, ...authHeaders},
      ).timeout(Duration(seconds: _config.requestTimeoutSeconds));

      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorType.networkError,
        'Failed to fetch incident: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Update incident status (official/admin only)
  Future<Map<String, dynamic>> updateIncidentStatus({
    required String incidentId,
    required String status,
    String? internalNotes,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/incidents/$incidentId/status');
      final authHeaders = await _authHeaders();
      final response = await _httpClient.patch(
        uri,
        headers: {..._headers, ...authHeaders},
        body: json.encode({
          'status': status,
          'internal_notes': internalNotes,
        }),
      ).timeout(Duration(seconds: _config.requestTimeoutSeconds));

      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorType.networkError,
        'Failed to update incident: ${e.toString()}',
        originalError: e,
      );
    }
  }

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

  void _validateDescription(String description) {
    if (description.length > 1000) {
      throw ApiException(
        ApiErrorType.validationError,
        'Description too long. Maximum 1000 characters.',
      );
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = json.decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {'data': body};
    }

    final detail = body['detail'] ?? 'Unknown error';

    switch (response.statusCode) {
      case 400:
        throw ApiException(ApiErrorType.validationError, detail, statusCode: 400);
      case 401:
        throw ApiException(ApiErrorType.unauthorized, detail, statusCode: 401);
      case 403:
        throw ApiException(ApiErrorType.forbidden, detail, statusCode: 403);
      case 404:
        throw ApiException(ApiErrorType.validationError, detail, statusCode: 404);
      case 413:
        throw ApiException(ApiErrorType.validationError, 'File too large', statusCode: 413);
      case 415:
        throw ApiException(ApiErrorType.validationError, 'Unsupported file format', statusCode: 415);
      case 429:
        throw ApiException(ApiErrorType.networkError, 'Rate limit exceeded. Try again later.', statusCode: 429);
      case 503:
        throw ApiException(ApiErrorType.serverError, 'Service unavailable', statusCode: 503);
      default:
        throw ApiException(ApiErrorType.serverError, detail, statusCode: response.statusCode);
    }
  }
}
