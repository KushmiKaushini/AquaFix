import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/queued_incident_model.dart';
import 'api_service.dart';
import 'api_exceptions.dart';

class SyncResult {
  final int total;
  final int succeeded;
  final int failed;

  const SyncResult({
    required this.total,
    required this.succeeded,
    required this.failed,
  });

  bool get isFullSuccess => total > 0 && failed == 0;
  bool get hasFailures => failed > 0;
}

/// Abstract storage contract enabling pure unit tests without platform channel dependencies.
abstract class OfflineStorageAdapter {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureStorageAdapter implements OfflineStorageAdapter {
  final FlutterSecureStorage _storage;

  const SecureStorageAdapter([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemoryStorageAdapter implements OfflineStorageAdapter {
  final Map<String, String> _memory = {};

  @override
  Future<String?> read(String key) async => _memory[key];

  @override
  Future<void> write(String key, String value) async {
    _memory[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _memory.remove(key);
  }
}

class OfflineQueueService {
  static const String queueStorageKey = 'aquafix_offline_incident_queue';
  final OfflineStorageAdapter _storage;

  OfflineQueueService({OfflineStorageAdapter? storage})
      : _storage = storage ?? const SecureStorageAdapter();

  /// Retrieve all incidents queued for offline submission.
  Future<List<QueuedIncident>> getQueue() async {
    try {
      final raw = await _storage.read(queueStorageKey);
      if (raw == null || raw.trim().isEmpty) {
        return [];
      }
      final List<dynamic> list = json.decode(raw);
      return list
          .map((item) => QueuedIncident.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Add a newly captured incident to the offline queue.
  Future<void> enqueue(QueuedIncident incident) async {
    final current = await getQueue();
    current.add(incident);
    await _saveQueue(current);
  }

  /// Remove a successfully submitted incident from the offline queue.
  Future<void> dequeue(String id) async {
    final current = await getQueue();
    current.removeWhere((item) => item.id == id);
    await _saveQueue(current);
  }

  /// Clear the entire offline queue.
  Future<void> clearQueue() async {
    await _storage.delete(queueStorageKey);
  }

  /// Return count of pending incidents in the offline queue.
  Future<int> getQueueLength() async {
    final queue = await getQueue();
    return queue.length;
  }

  /// Flush the queue by attempting to submit each incident to the API.
  Future<SyncResult> syncQueue(ApiService apiService) async {
    final queue = await getQueue();
    if (queue.isEmpty) {
      return const SyncResult(total: 0, succeeded: 0, failed: 0);
    }

    int succeeded = 0;
    int failed = 0;
    final List<QueuedIncident> remaining = [];

    for (final item in queue) {
      try {
        await apiService.submitIncident(
          imagePath: item.imagePath,
          latitude: item.latitude,
          longitude: item.longitude,
          description: item.description,
          category: item.category,
          severity: item.severity,
          skipAi: item.skipAi,
        );
        succeeded++;
      } on ApiException catch (e) {
        // If it's a validation error (e.g. image file missing on disk), drop it or increment retry
        if (e.type == ApiErrorType.validationError) {
          failed++;
        } else {
          // Network error: retain in queue with incremented retry count
          failed++;
          remaining.add(item.copyWith(retryCount: item.retryCount + 1));
        }
      } catch (e) {
        failed++;
        remaining.add(item.copyWith(retryCount: item.retryCount + 1));
      }
    }

    await _saveQueue(remaining);

    return SyncResult(
      total: queue.length,
      succeeded: succeeded,
      failed: failed,
    );
  }

  Future<void> _saveQueue(List<QueuedIncident> queue) async {
    if (queue.isEmpty) {
      await _storage.delete(queueStorageKey);
    } else {
      final raw = json.encode(queue.map((item) => item.toJson()).toList());
      await _storage.write(queueStorageKey, raw);
    }
  }
}

/// Riverpod provider for OfflineQueueService
final offlineQueueServiceProvider = Provider<OfflineQueueService>((ref) {
  return OfflineQueueService();
});
