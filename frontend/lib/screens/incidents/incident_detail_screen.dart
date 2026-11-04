import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/incident_model.dart';
import '../../providers/app_providers.dart';
import '../../widgets/status_update_dialog.dart';

class IncidentDetailScreen extends ConsumerStatefulWidget {
  final IncidentModel incident;

  const IncidentDetailScreen({super.key, required this.incident});

  @override
  ConsumerState<IncidentDetailScreen> createState() =>
      _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends ConsumerState<IncidentDetailScreen> {
  late IncidentModel _currentIncident;
  List<IncidentAuditModel>? _resolutionHistory;
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _currentIncident = widget.incident;
    _resolutionHistory = widget.incident.history;
    if (_resolutionHistory == null || _resolutionHistory!.isEmpty) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });
    try {
      final apiService = ref.read(apiServiceProvider);
      final rawList = await apiService.getIncidentHistory(_currentIncident.id);
      if (mounted) {
        setState(() {
          _resolutionHistory = rawList
              .map((item) =>
                  IncidentAuditModel.fromJson(item as Map<String, dynamic>))
              .toList();
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'update') {
                await showDialog(
                  context: context,
                  builder: (_) => StatusUpdateDialog(incident: _currentIncident),
                );
                // Refresh history after dialog close
                _loadHistory();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'update',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Update Status / Priority'),
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
            // Status and Severity badges row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: _currentIncident.statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _currentIncident.statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _currentIncident.categoryIcon,
                        color: _currentIncident.statusColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentIncident.statusDisplayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: _currentIncident.statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Severity badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: _currentIncident.severityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _currentIncident.severityColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _currentIncident.severityIcon,
                        color: _currentIncident.severityColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Priority: ${_currentIncident.severityDisplayName}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: _currentIncident.severityColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Image (if available)
            if (_currentIncident.imageUrl != null &&
                _currentIncident.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  _currentIncident.imageUrl!,
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 44,
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
            const SizedBox(height: 20),

            // Category
            Text(
              'Category',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _currentIncident.category,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            if (_currentIncident.description != null &&
                _currentIncident.description!.isNotEmpty) ...[
              Text(
                'Description',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currentIncident.description!,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
            ],

            // AI Analysis Insights Card (if available)
            if (_currentIncident.aiAnalysis != null) ...[
              Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFF38BDF8),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'AI Image Analysis Insights',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: const Color(0xFF38BDF8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_currentIncident.aiAnalysis!['confidence'] != null)
                        Text(
                          'Analysis Confidence: ${((_currentIncident.aiAnalysis!['confidence'] as num) * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      if (_currentIncident.aiAnalysis!['reasoning'] != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _currentIncident.aiAnalysis!['reasoning'].toString(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                      if (_currentIncident.aiAnalysis!['visual_markers'] is List) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: (_currentIncident.aiAnalysis!['visual_markers'] as List)
                              .map(
                                (m) => Chip(
                                  label: Text(
                                    m.toString(),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'ℹ️ Gemini AI analysis provides transparent diagnostic cues to support human inspection.',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
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
                  '${_currentIncident.latitude.toStringAsFixed(6)}, ${_currentIncident.longitude.toStringAsFixed(6)}',
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
                    initialCenter: LatLng(
                        _currentIncident.latitude, _currentIncident.longitude),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.aquafix',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_currentIncident.latitude,
                              _currentIncident.longitude),
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
            const SizedBox(height: 24),

            // Resolution History / Audit Trail
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Resolution Lifecycle & History',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_isLoadingHistory)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_resolutionHistory != null && _resolutionHistory!.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _resolutionHistory!.length,
                itemBuilder: (context, index) {
                  final item = _resolutionHistory![index];
                  final isLast = index == _resolutionHistory!.length - 1;
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isLast
                                    ? theme.colorScheme.primary
                                    : Colors.white38,
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: Colors.white24,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item.oldStatus != null
                                          ? '${item.oldStatus} ➔ ${item.newStatus}'
                                          : item.newStatus,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      _formatDateTime(item.changedAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.internalNotes != null &&
                                    item.internalNotes!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.internalNotes!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                                if (item.modifierName != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'By: ${item.modifierName}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Reported on ${_formatDateTime(_currentIncident.createdAt)}. Awaiting official status updates.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
