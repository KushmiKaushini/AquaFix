import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../lib/models/incident_model.dart';
import '../lib/models/user_model.dart';
import '../lib/utils/validators.dart';

void main() {
  group('IncidentModel', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': '123e4567-e89b-12d3-a456-426614174000',
        'status': 'Pending',
        'category': 'Pipeline Leak',
        'description': 'Test leak',
        'image_url': '/uploads/test.jpg',
        'latitude': 6.9271,
        'longitude': 79.8612,
        'created_at': '2026-06-28T10:00:00Z',
        'updated_at': '2026-06-28T10:00:00Z',
      };

      final incident = IncidentModel.fromJson(json);

      expect(incident.id, '123e4567-e89b-12d3-a456-426614174000');
      expect(incident.status, IncidentStatus.pending);
      expect(incident.category, 'Pipeline Leak');
      expect(incident.latitude, 6.9271);
      expect(incident.longitude, 79.8612);
    });

    test('status display names are correct', () {
      final pending = IncidentModel(
        id: '1',
        status: IncidentStatus.pending,
        category: 'Test',
        latitude: 0,
        longitude: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(pending.statusDisplayName, 'Pending');

      final inProgress = IncidentModel(
        id: '2',
        status: IncidentStatus.inProgress,
        category: 'Test',
        latitude: 0,
        longitude: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(inProgress.statusDisplayName, 'In Progress');

      final resolved = IncidentModel(
        id: '3',
        status: IncidentStatus.resolved,
        category: 'Test',
        latitude: 0,
        longitude: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(resolved.statusDisplayName, 'Resolved');
    });

    test('statusColor returns correct colors', () {
      final pending = IncidentModel(
        id: '4',
        status: IncidentStatus.pending,
        category: 'Test',
        latitude: 0,
        longitude: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(pending.statusColor, const Color(0xFFF59E0B));

      final resolved = IncidentModel(
        id: '5',
        status: IncidentStatus.resolved,
        category: 'Test',
        latitude: 0,
        longitude: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(resolved.statusColor, const Color(0xFF10B981));
    });
  });

  group('UserModel', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': '123e4567-e89b-12d3-a456-426614174000',
        'email': 'test@aquafix.com',
        'full_name': 'Test User',
        'role': 'citizen',
        'created_at': '2026-06-28T10:00:00Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.email, 'test@aquafix.com');
      expect(user.fullName, 'Test User');
      expect(user.role, UserRole.citizen);
    });
  });

  group('Validators', () {
    test('validateCoordinates accepts valid coords', () {
      expect(Validators.validateCoordinates(6.9271, 79.8612), isNull);
    });

    test('validateCoordinates rejects invalid latitude', () {
      expect(Validators.validateCoordinates(91, 0), isNotNull);
    });

    test('validateCoordinates rejects invalid longitude', () {
      expect(Validators.validateCoordinates(0, 181), isNotNull);
    });

    test('validateImageExtension accepts valid extensions', () {
      expect(Validators.validateImageExtension('photo.jpg'), isNull);
      expect(Validators.validateImageExtension('photo.png'), isNull);
      expect(Validators.validateImageExtension('photo.webp'), isNull);
    });

    test('validateImageExtension rejects invalid extensions', () {
      expect(Validators.validateImageExtension('file.pdf'), isNotNull);
    });

    test('validateFileSize accepts valid size', () {
      expect(Validators.validateFileSize(1024 * 1024), isNull); // 1MB
    });

    test('validateFileSize rejects oversized files', () {
      expect(Validators.validateFileSize(6 * 1024 * 1024), isNotNull); // 6MB > 5MB limit
    });
  });
}
