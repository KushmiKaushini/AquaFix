/// API endpoint constants
class ApiConstants {
  static const String reportIncident = '/incidents/report';
  static const String loginEndpoint = '/auth/login';
  static const String logoutEndpoint = '/auth/logout';
}

/// File constraints
class FileConstants {
  static const int maxFileSize = 5 * 1024 * 1024; // 5 MB
  static const List<String> allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
  ];
  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];
}

/// Description constraints
class DescriptionConstants {
  static const int maxLength = 1000;
  static const int minLength = 0;
}

/// Error messages
class ErrorMessages {
  static const String noImage =
      'Please capture or upload an incident photo first';
  static const String noLocation =
      'GPS coordinates are required. Please tap "Get GPS"';
  static const String descriptionTooLong =
      'Description cannot exceed ${DescriptionConstants.maxLength} characters';
  static const String fileTooLarge = 'File too large. Maximum size is 5MB.';
  static const String invalidFormat =
      'Invalid file format. Supported: JPEG, PNG, WebP';
  static const String networkError =
      'No internet connection. Please check your network and try again.';
  static const String timeoutError =
      'Request timed out. Please check your connection and try again.';
}
