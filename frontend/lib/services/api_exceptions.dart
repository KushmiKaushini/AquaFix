/// Error types for the API
enum ApiErrorType {
  networkError,
  timeout,
  unauthorized,
  forbidden,
  validationError,
  serverError,
  unknown,
}

/// Exception thrown by API calls
class ApiException implements Exception {
  final ApiErrorType type;
  final String message;
  final int? statusCode;
  final dynamic originalError;

  ApiException(
    this.type,
    this.message, {
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => message;

  String get userFriendlyMessage {
    switch (type) {
      case ApiErrorType.networkError:
        return 'No internet connection. Please check your network and try again.';
      case ApiErrorType.timeout:
        return 'Request timed out. Please check your connection and try again.';
      case ApiErrorType.unauthorized:
        return 'Unauthorized. Please log in again.';
      case ApiErrorType.forbidden:
        return 'You do not have permission to perform this action.';
      case ApiErrorType.validationError:
        return message;
      case ApiErrorType.serverError:
        return 'Server error. Please try again later.';
      case ApiErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}
