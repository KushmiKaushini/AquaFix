/// Input validation utilities
class Validators {
  /// Validate coordinates
  static String? validateCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return 'GPS coordinates are required';
    }

    if (latitude < -90 || latitude > 90) {
      return 'Invalid latitude. Must be between -90 and 90.';
    }

    if (longitude < -180 || longitude > 180) {
      return 'Invalid longitude. Must be between -180 and 180.';
    }

    return null;
  }

  /// Validate image file extension
  static String? validateImageExtension(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    const allowed = ['jpg', 'jpeg', 'png', 'webp'];

    if (!allowed.contains(extension)) {
      return 'Invalid image format. Supported: ${allowed.join(', ')}';
    }

    return null;
  }

  /// Validate file size
  static String? validateFileSize(int fileSize) {
    const maxSize = 5 * 1024 * 1024; // 5 MB

    if (fileSize > maxSize) {
      final sizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      return 'File too large ($sizeMb MB). Maximum size is 5 MB.';
    }

    if (fileSize == 0) {
      return 'Image file is empty.';
    }

    return null;
  }

  /// Validate description
  static String? validateDescription(String? description) {
    if (description != null && description.length > 1000) {
      return 'Description too long. Maximum 1000 characters.';
    }

    return null;
  }
}
