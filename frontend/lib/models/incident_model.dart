import 'package:flutter/material.dart';

enum IncidentStatus { pending, inProgress, resolved, rejected }

class IncidentAuditModel {
  final String id;
  final String incidentId;
  final String? modifiedBy;
  final String? modifierName;
  final String? oldStatus;
  final String newStatus;
  final String? internalNotes;
  final DateTime changedAt;

  IncidentAuditModel({
    required this.id,
    required this.incidentId,
    this.modifiedBy,
    this.modifierName,
    this.oldStatus,
    required this.newStatus,
    this.internalNotes,
    required this.changedAt,
  });

  factory IncidentAuditModel.fromJson(Map<String, dynamic> json) {
    return IncidentAuditModel(
      id: json['id']?.toString() ?? '',
      incidentId: json['incident_id']?.toString() ?? '',
      modifiedBy: json['modified_by']?.toString(),
      modifierName: json['modifier_name'] ?? 'System / Official',
      oldStatus: json['old_status'],
      newStatus: json['new_status'] ?? 'Pending',
      internalNotes: json['internal_notes'],
      changedAt: json['changed_at'] != null
          ? DateTime.parse(json['changed_at'])
          : DateTime.now(),
    );
  }
}

class IncidentModel {
  final String id;
  final IncidentStatus status;
  final String category;
  final String severity; // Low, Medium, High, Critical
  final String? description;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reporterName;
  final Map<String, dynamic>? aiAnalysis;
  final List<IncidentAuditModel>? history;

  IncidentModel({
    required this.id,
    required this.status,
    required this.category,
    this.severity = 'Medium',
    this.description,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.updatedAt,
    this.reporterName,
    this.aiAnalysis,
    this.history,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    List<IncidentAuditModel>? parsedHistory;
    if (json['history'] is List) {
      parsedHistory = (json['history'] as List)
          .map((item) => IncidentAuditModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return IncidentModel(
      id: json['id']?.toString() ?? '',
      status: IncidentStatus.values.firstWhere(
        (e) => e.name == _mapStatus(json['status']?.toString() ?? 'Pending'),
        orElse: () => IncidentStatus.pending,
      ),
      category: json['category'] ?? 'Public Sanitation Issue',
      severity: json['severity']?.toString() ?? 'Medium',
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
      aiAnalysis: json['ai_analysis'] is Map<String, dynamic>
          ? json['ai_analysis'] as Map<String, dynamic>
          : null,
      history: parsedHistory,
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

  String get severityDisplayName {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return severity;
    }
  }

  Color get severityColor {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFDC2626); // Bright red
      case 'high':
        return const Color(0xFFEA580C); // Deep orange
      case 'medium':
        return const Color(0xFFF59E0B); // Amber
      case 'low':
        return const Color(0xFF10B981); // Emerald green
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData get severityIcon {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.dangerous;
      case 'high':
        return Icons.warning_amber_rounded;
      case 'medium':
        return Icons.info_outline;
      case 'low':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
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
