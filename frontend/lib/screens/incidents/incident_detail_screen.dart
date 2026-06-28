import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/incident_model.dart';
import '../../widgets/status_update_dialog.dart';

class IncidentDetailScreen extends ConsumerWidget {
  final IncidentModel incident;

  const IncidentDetailScreen({super.key, required this.incident});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'update') {
                showDialog(
                  context: context,
                  builder: (_) => StatusUpdateDialog(incident: incident),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'update',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Update Status'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: incident.statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: incident.statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      incident.categoryIcon,
                      color: incident.statusColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      incident.statusDisplayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: incident.statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Image (if available)
            if (incident.imageUrl != null && incident.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  incident.imageUrl!,
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 250,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Image unavailable',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // Category
            Text(
              'Category',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              incident.category,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            if (incident.description != null &&
                incident.description!.isNotEmpty) ...[
              Text(
                'Description',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                incident.description!,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
            ],

            // Location
            Text(
              'Location',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${incident.latitude.toStringAsFixed(6)}, ${incident.longitude.toStringAsFixed(6)}',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Map
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(incident.latitude, incident.longitude),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.aquafix',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(incident.latitude, incident.longitude),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dates
            Text(
              'Timeline',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            _buildTimelineItem(
              theme,
              'Reported',
              incident.createdAt,
              Icons.flag,
            ),
            if (incident.updatedAt != incident.createdAt)
              _buildTimelineItem(
                theme,
                'Last Updated',
                incident.updatedAt,
                Icons.update,
              ),

            const SizedBox(height: 24),

            // Reporter
            if (incident.reporterName != null) ...[
              Text(
                'Reported By',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.person, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    incident.reporterName!,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    ThemeData theme,
    String label,
    DateTime date,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              Text(
                _formatDateTime(date),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
