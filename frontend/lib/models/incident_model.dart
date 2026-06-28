import 'package:flutter/material.dart';

enum IncidentStatus { pending, inProgress, resolved, rejected }

class IncidentModel {
  final String id;
  final IncidentStatus status;
  final String category;
  final String? description;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reporterName;

  IncidentModel({
    required this.id,
    required this.status,
    required this.category,
    this.description,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.updatedAt,
    this.reporterName,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id']?.toString() ?? '',
      status: IncidentStatus.values.firstWhere(
        (e) => e.name == _mapStatus(json['status']?.toString() ?? 'Pending'),
        orElse: () => IncidentStatus.pending,
      ),
      category: json['category'] ?? 'Unknown',
      description: json['description'],
      imageUrl: json['image_url'],
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      reporterName: json['reporter_name'],
    );
  }

  static String _mapStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'pending';
      case 'in progress':
        return 'inProgress';
      case 'resolved':
        return 'resolved';
      case 'rejected':
        return 'rejected';
      default:
        return 'pending';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case IncidentStatus.pending:
        return 'Pending';
      case IncidentStatus.inProgress:
        return 'In Progress';
      case IncidentStatus.resolved:
        return 'Resolved';
      case IncidentStatus.rejected:
        return 'Rejected';
    }
  }

  Color get statusColor {
    switch (status) {
      case IncidentStatus.pending:
        return const Color(0xFFF59E0B);
      case IncidentStatus.inProgress:
        return const Color(0xFF3B82F6);
      case IncidentStatus.resolved:
        return const Color(0xFF10B981);
      case IncidentStatus.rejected:
        return const Color(0xFFEF4444);
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'pipeline leak':
        return Icons.water_drop;
      case 'drainage blockage':
        return Icons.block;
      case 'overflowing sewage':
        return Icons.warning;
      case 'road sinkhole':
        return Icons.terrain;
      default:
        return Icons.report_problem;
    }
  }
}
