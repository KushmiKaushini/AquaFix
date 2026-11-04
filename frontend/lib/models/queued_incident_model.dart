class QueuedIncident {
  final String id;
  final String imagePath;
  final double latitude;
  final double longitude;
  final String description;
  final String? category;
  final String? severity;
  final bool skipAi;
  final DateTime createdAt;
  final int retryCount;

  QueuedIncident({
    required this.id,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    required this.description,
    this.category,
    this.severity,
    this.skipAi = false,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'category': category,
      'severity': severity,
      'skipAi': skipAi,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
    };
  }

  factory QueuedIncident.fromJson(Map<String, dynamic> json) {
    return QueuedIncident(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: json['description'] as String,
      category: json['category'] as String?,
      severity: json['severity'] as String?,
      skipAi: json['skipAi'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  QueuedIncident copyWith({
    String? id,
    String? imagePath,
    double? latitude,
    double? longitude,
    String? description,
    String? category,
    String? severity,
    bool? skipAi,
    DateTime? createdAt,
    int? retryCount,
  }) {
    return QueuedIncident(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      skipAi: skipAi ?? this.skipAi,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
