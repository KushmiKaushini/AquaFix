import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/incident_model.dart';
import '../../providers/app_providers.dart';

class StatusUpdateDialog extends ConsumerStatefulWidget {
  final IncidentModel incident;

  const StatusUpdateDialog({super.key, required this.incident});

  @override
  ConsumerState<StatusUpdateDialog> createState() => _StatusUpdateDialogState();
}

class _StatusUpdateDialogState extends ConsumerState<StatusUpdateDialog> {
  String? _selectedStatus;
  final _notesController = TextEditingController();
  bool _isUpdating = false;

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': 'In Progress', 'label': 'In Progress', 'color': const Color(0xFF3B82F6)},
    {'value': 'Resolved', 'label': 'Resolved', 'color': const Color(0xFF10B981)},
    {'value': 'Rejected', 'label': 'Rejected', 'color': const Color(0xFFEF4444)},
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus() async {
    if (_selectedStatus == null) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.updateIncidentStatus(
        incidentId: widget.incident.id,
        status: _selectedStatus!,
        internalNotes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $_selectedStatus'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        // Refresh incidents
        ref.read(incidentsProvider.notifier).fetchIncidents(refresh: true);
      }
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: const Text('Update Incident Status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current: ${widget.incident.statusDisplayName}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          const Text('New Status:'),
          const SizedBox(height: 8),
          ..._statusOptions.map((option) {
            return RadioListTile<String>(
              title: Text(option['label']),
              value: option['value'],
              groupValue: _selectedStatus,
              activeColor: option['color'],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            );
          }),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Internal Notes (Optional)',
              hintText: 'Add notes about the status change...',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUpdating || _selectedStatus == null
              ? null
              : _updateStatus,
          child: _isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}
