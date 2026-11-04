import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../services/offline_queue_service.dart';
import '../../config/app_config.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushEnabled = true;
  bool _statusAlerts = true;
  bool _highSeverityAlerts = true;
  bool _wifiOnlySync = false;
  int _pendingQueueCount = 0;
  bool _isSyncing = false;
  String _serverStatus = 'Checking...';
  bool _isServerHealthy = false;
  bool _isRegisteringDevice = false;

  @override
  void initState() {
    super.initState();
    _loadPendingQueueCount();
    _checkServer();
  }

  Future<void> _loadPendingQueueCount() async {
    final queueService = ref.read(offlineQueueServiceProvider);
    final count = await queueService.getQueueLength();
    if (mounted) {
      setState(() {
        _pendingQueueCount = count;
      });
    }
  }

  Future<void> _checkServer() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final health = await apiService.checkHealth();
      if (mounted) {
        setState(() {
          _isServerHealthy = health['status'] == 'healthy';
          _serverStatus = _isServerHealthy ? 'Connected & Healthy' : 'Degraded';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isServerHealthy = false;
          _serverStatus = 'Unreachable';
        });
      }
    }
  }

  Future<void> _forceSyncQueue() async {
    setState(() => _isSyncing = true);
    final queueService = ref.read(offlineQueueServiceProvider);
    final apiService = ref.read(apiServiceProvider);

    final result = await queueService.syncQueue(apiService);
    await _loadPendingQueueCount();

    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isFullSuccess
                ? 'Synced ${result.succeeded} offline reports successfully!'
                : result.total == 0
                    ? 'Offline queue is empty'
                    : 'Synced ${result.succeeded}/${result.total} reports (${result.failed} retrying)',
          ),
          backgroundColor: result.isFullSuccess ? const Color(0xFF10B981) : Colors.orange,
        ),
      );
    }
  }

  Future<void> _registerDeviceToken() async {
    setState(() => _isRegisteringDevice = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final mockDeviceToken = 'fcm-device-${DateTime.now().millisecondsSinceEpoch}';
      await apiService.registerDeviceToken(mockDeviceToken);
      if (mounted) {
        setState(() => _isRegisteringDevice = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Device registered for real-time status push alerts!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegisteringDevice = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register device: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = getAppConfig();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: Notifications
          _buildSectionHeader(theme, 'Notification Preferences'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive real-time mobile push notifications'),
                  value: _pushEnabled,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) => setState(() => _pushEnabled = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Status Updates'),
                  subtitle: const Text('Notify when officials change incident progress'),
                  value: _statusAlerts,
                  activeColor: theme.colorScheme.primary,
                  onChanged: _pushEnabled ? (val) => setState(() => _statusAlerts = val) : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('High Severity & Critical Alerts'),
                  subtitle: const Text('Receive immediate broadcast for major leaks'),
                  value: _highSeverityAlerts,
                  activeColor: theme.colorScheme.primary,
                  onChanged: _pushEnabled ? (val) => setState(() => _highSeverityAlerts = val) : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phonelink_setup, color: Color(0xFF38BDF8)),
                  title: const Text('Register Device for Push Alerts'),
                  subtitle: const Text('Sync device token with municipal dispatch gateway'),
                  trailing: _isRegisteringDevice
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  onTap: _isRegisteringDevice ? null : _registerDeviceToken,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Offline & Synchronization
          _buildSectionHeader(theme, 'Offline & Synchronization'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.cloud_sync,
                    color: _pendingQueueCount > 0 ? Colors.orange : const Color(0xFF10B981),
                  ),
                  title: const Text('Offline Incident Queue'),
                  subtitle: Text(
                    _pendingQueueCount == 0
                        ? 'All reports synchronized'
                        : '$_pendingQueueCount report(s) waiting for sync',
                  ),
                  trailing: _isSyncing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : ElevatedButton(
                          onPressed: _pendingQueueCount > 0 ? _forceSyncQueue : null,
                          child: const Text('Sync Now'),
                        ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Sync on Wi-Fi Only'),
                  subtitle: const Text('Save mobile cellular data when uploading photos'),
                  value: _wifiOnlySync,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) => setState(() => _wifiOnlySync = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: Server & Environment Diagnostics
          _buildSectionHeader(theme, 'Server & Diagnostics'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 14,
                    color: _isServerHealthy ? const Color(0xFF10B981) : Colors.red,
                  ),
                  title: const Text('API Gateway Status'),
                  subtitle: Text(_serverStatus),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _checkServer,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('API Endpoint'),
                  subtitle: Text(
                    config.apiBaseUrl,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
