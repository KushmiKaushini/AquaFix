import 'package:flutter_test/flutter_test.dart';
import 'package:aquafix/models/queued_incident_model.dart';
import 'package:aquafix/services/offline_queue_service.dart';
import 'package:aquafix/services/api_service.dart';
import 'package:aquafix/services/api_exceptions.dart';

// Mock ApiService for testing queue sync
class MockApiService extends ApiService {
  MockApiService() : super();

  bool shouldFailWithNetworkError = false;
  final List<Map<String, dynamic>> submittedIncidents = [];

  @override
  Future<Map<String, dynamic>> submitIncident({
    required String imagePath,
    required double latitude,
    required double longitude,
    required String description,
    String? category,
    String? severity,
    bool skipAi = false,
  }) async {
    if (shouldFailWithNetworkError) {
      throw ApiException(
        ApiErrorType.networkError,
        'Simulated network disconnect',
      );
    }

    final record = {
      'imagePath': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'category': category,
      'severity': severity,
      'skipAi': skipAi,
    };
    submittedIncidents.add(record);
    return {'id': 'mock-synced-id', ...record};
  }
}

void main() {
  group('QueuedIncident Model', () {
    test('toJson and fromJson round-trip successfully', () {
      final now = DateTime(2026, 11, 4, 15, 30);
      final original = QueuedIncident(
        id: 'q-101',
        imagePath: '/tmp/leak.jpg',
        latitude: 6.9271,
        longitude: 79.8612,
        description: 'Burst water pipe flooding street',
        category: 'Pipeline Leak',
        severity: 'Critical',
        skipAi: true,
        createdAt: now,
        retryCount: 1,
      );

      final jsonMap = original.toJson();
      final restored = QueuedIncident.fromJson(jsonMap);

      expect(restored.id, 'q-101');
      expect(restored.imagePath, '/tmp/leak.jpg');
      expect(restored.latitude, 6.9271);
      expect(restored.longitude, 79.8612);
      expect(restored.description, 'Burst water pipe flooding street');
      expect(restored.category, 'Pipeline Leak');
      expect(restored.severity, 'Critical');
      expect(restored.skipAi, isTrue);
      expect(restored.createdAt, now);
      expect(restored.retryCount, 1);
    });
  });

  group('OfflineQueueService', () {
    late MemoryStorageAdapter memoryStorage;
    late OfflineQueueService queueService;

    setUp(() {
      memoryStorage = MemoryStorageAdapter();
      queueService = OfflineQueueService(storage: memoryStorage);
    });

    test('starts with an empty queue', () async {
      final items = await queueService.getQueue();
      expect(items, isEmpty);
      expect(await queueService.getQueueLength(), 0);
    });

    test('enqueues items in FIFO order', () async {
      final item1 = QueuedIncident(
        id: 'q-1',
        imagePath: '/path/1.jpg',
        latitude: 6.9,
        longitude: 79.8,
        description: 'Item 1',
        createdAt: DateTime.now(),
      );
      final item2 = QueuedIncident(
        id: 'q-2',
        imagePath: '/path/2.jpg',
        latitude: 6.95,
        longitude: 79.85,
        description: 'Item 2',
        createdAt: DateTime.now(),
      );

      await queueService.enqueue(item1);
      await queueService.enqueue(item2);

      final queue = await queueService.getQueue();
      expect(queue.length, 2);
      expect(queue[0].id, 'q-1');
      expect(queue[1].id, 'q-2');
    });

    test('dequeues specific item by id', () async {
      final item1 = QueuedIncident(
        id: 'q-1',
        imagePath: '/path/1.jpg',
        latitude: 6.9,
        longitude: 79.8,
        description: 'Item 1',
        createdAt: DateTime.now(),
      );
      final item2 = QueuedIncident(
        id: 'q-2',
        imagePath: '/path/2.jpg',
        latitude: 6.95,
        longitude: 79.85,
        description: 'Item 2',
        createdAt: DateTime.now(),
      );

      await queueService.enqueue(item1);
      await queueService.enqueue(item2);

      await queueService.dequeue('q-1');

      final queue = await queueService.getQueue();
      expect(queue.length, 1);
      expect(queue.first.id, 'q-2');
    });

    test('clears entire queue', () async {
      await queueService.enqueue(
        QueuedIncident(
          id: 'q-1',
          imagePath: '/path/1.jpg',
          latitude: 6.9,
          longitude: 79.8,
          description: 'Item 1',
          createdAt: DateTime.now(),
        ),
      );

      await queueService.clearQueue();
      expect(await queueService.getQueueLength(), 0);
    });

    test('syncQueue flushes items successfully to ApiService', () async {
      final mockApi = MockApiService();

      await queueService.enqueue(
        QueuedIncident(
          id: 'q-1',
          imagePath: '/path/1.jpg',
          latitude: 6.9,
          longitude: 79.8,
          description: 'Burst main',
          category: 'Pipeline Leak',
          severity: 'High',
          createdAt: DateTime.now(),
        ),
      );

      final result = await queueService.syncQueue(mockApi);

      expect(result.total, 1);
      expect(result.succeeded, 1);
      expect(result.failed, 0);
      expect(result.isFullSuccess, isTrue);
      expect(mockApi.submittedIncidents.length, 1);
      expect(await queueService.getQueueLength(), 0);
    });

    test('syncQueue preserves items in queue when network error occurs', () async {
      final mockApi = MockApiService();
      mockApi.shouldFailWithNetworkError = true;

      await queueService.enqueue(
        QueuedIncident(
          id: 'q-offline',
          imagePath: '/path/offline.jpg',
          latitude: 6.9,
          longitude: 79.8,
          description: 'Queued item',
          createdAt: DateTime.now(),
        ),
      );

      final result = await queueService.syncQueue(mockApi);

      expect(result.total, 1);
      expect(result.succeeded, 0);
      expect(result.failed, 1);
      expect(result.hasFailures, isTrue);

      final remaining = await queueService.getQueue();
      expect(remaining.length, 1);
      expect(remaining.first.retryCount, 1);
    });
  });
}
