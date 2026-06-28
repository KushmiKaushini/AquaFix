import 'package:flutter/material.dart';

enum UserRole { citizen, official, admin }

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.role = UserRole.citizen,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == (json['role'] ?? 'citizen'),
        orElse: () => UserRole.citizen,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.name,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get roleDisplayName {
    switch (role) {
      case UserRole.citizen:
        return 'Citizen';
      case UserRole.official:
        return 'Official';
      case UserRole.admin:
        return 'Admin';
    }
  }

  Color get roleColor {
    switch (role) {
      case UserRole.citizen:
        return const Color(0xFF3B82F6);
      case UserRole.official:
        return const Color(0xFF10B981);
      case UserRole.admin:
        return const Color(0xFFF59E0B);
    }
  }
}
