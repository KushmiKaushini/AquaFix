import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/app_providers.dart';
import '../../widgets/ui_components.dart';
import '../incidents/incidents_list_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(incidentsProvider.notifier).fetchIncidents(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incidentsState = ref.watch(incidentsProvider);
    final incidents = incidentsState.incidents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(incidentsProvider.notifier).fetchIncidents(refresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero stats row
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Total',
                      '${incidents.length}',
                      Icons.flag_rounded,
                      theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Pending',
                      '${incidents.where((i) => i['status'] == 'Pending').length}',
                      Icons.schedule_rounded,
                      const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'In Progress',
                      '${incidents.where((i) => i['status'] == 'In Progress').length}',
                      Icons.construction_rounded,
                      const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Resolved',
                      '${incidents.where((i) => i['status'] == 'Resolved').length}',
                      Icons.check_circle_rounded,
                      const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Section header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Incident Map', style: theme.textTheme.titleMedium),
                  TextButton(
                    onPressed: () => _showFullList(context),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Map preview
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 220,
                  child: incidents.isEmpty
                      ? _buildMapPlaceholder(context)
                      : FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              incidents.first['latitude'] ?? 6.9271,
                              incidents.first['longitude'] ?? 79.8612,
                            ),
                            initialZoom: 12.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.aquafix',
                            ),
                            MarkerLayer(
                              markers: incidents.take(20).map((inc) {
                                return Marker(
                                  point: LatLng(
                                    inc['latitude'] ?? 6.9271,
                                    inc['longitude'] ?? 79.8612,
                                  ),
                                  width: 36,
                                  height: 36,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _statusColor(inc['status']),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _statusColor(inc['status']).withValues(alpha: 0.5),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.location_on, size: 16, color: Colors.white),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Recent incidents
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Reports', style: theme.textTheme.titleMedium),
                  TextButton(
                    onPressed: () => _showFullList(context),
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (incidents.isEmpty)
                _buildEmptyState(context)
              else
                ...incidents.take(3).map((inc) => _buildIncidentTile(context, inc)),

              const SizedBox(height: 80), // bottom padding for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('No incidents mapped yet', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('Be the first to report!', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No incidents reported yet', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('Tap the + button to report an issue in your area', style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentTile(BuildContext context, Map<String, dynamic> incident) {
    final theme = Theme.of(context);
    final status = incident['status'] ?? 'Pending';
    final category = incident['category'] ?? 'Unknown';
    final color = _statusColor(status);

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_categoryIcon(category), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  incident['description'] ?? 'No description',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status, style: theme.textTheme.labelSmall?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return const Color(0xFFF59E0B);
      case 'in progress': return const Color(0xFF3B82F6);
      case 'resolved': return const Color(0xFF10B981);
      case 'rejected': return const Color(0xFFEF4444);
      default: return const Color(0xFF64748B);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'pipeline leak': return Icons.water_drop;
      case 'drainage blockage': return Icons.block;
      case 'overflowing sewage': return Icons.warning;
      case 'road sinkhole': return Icons.terrain;
      default: return Icons.report_problem;
    }
  }

  void _showFullList(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const IncidentsListScreen()),
    );
  }
}
