import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/app_providers.dart';
import '../../services/api_exceptions.dart';

class ReportIncidentScreen extends ConsumerStatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  ConsumerState<ReportIncidentScreen> createState() =>
      _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends ConsumerState<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  Position? _currentPosition;
  bool _isSubmitting = false;
  bool _isFetchingLocation = false;
  bool _isAnalyzingAi = false;
  bool _skipAi = false;
  String? _locationError;
  Map<String, dynamic>? _submissionResult;
  Map<String, dynamic>? _aiSuggestion;

  String _selectedCategory = 'Public Sanitation Issue';
  String _selectedSeverity = 'Medium';

  final List<String> _categories = [
    'Pipeline Leak',
    'Drainage Blockage',
    'Overflowing Sewage',
    'Road Sinkhole',
    'Public Sanitation Issue',
  ];

  final List<String> _severities = [
    'Low',
    'Medium',
    'High',
    'Critical',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1080,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _submissionResult = null;
          _aiSuggestion = null;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isFetchingLocation = false;
          _locationError = 'Location services are disabled';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isFetchingLocation = false;
            _locationError = 'Location permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isFetchingLocation = false;
          _locationError = 'Location permissions permanently denied';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentPosition = position;
        _isFetchingLocation = false;
      });
    } catch (e) {
      setState(() {
        _isFetchingLocation = false;
        _locationError = 'Failed to get location: ${e.toString()}';
      });
    }
  }

  Future<void> _analyzeWithAi() async {
    if (_selectedImage == null) {
      _showErrorSnackBar('Please select an incident photo first');
      return;
    }

    setState(() {
      _isAnalyzingAi = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final suggestion = await apiService.analyzeImage(_selectedImage!.path);

      setState(() {
        _aiSuggestion = suggestion;
        _isAnalyzingAi = false;
        // Pre-fill suggested category and severity if valid
        if (suggestion['category'] != null &&
            _categories.contains(suggestion['category'])) {
          _selectedCategory = suggestion['category'];
        }
        if (suggestion['severity'] != null &&
            _severities.contains(suggestion['severity'])) {
          _selectedSeverity = suggestion['severity'];
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Suggestion applied: ${_selectedCategory} (${_selectedSeverity} priority)',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF3B82F6),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isAnalyzingAi = false;
      });
      _showErrorSnackBar('AI suggestion unavailable. You can set category and severity manually.');
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage == null) {
      _showErrorSnackBar('Please capture or upload an incident photo');
      return;
    }

    if (_currentPosition == null) {
      _showErrorSnackBar('GPS coordinates are required. Please tap "Get GPS"');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionResult = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.submitIncident(
        imagePath: _selectedImage!.path,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        severity: _selectedSeverity,
        skipAi: _skipAi,
      );

      setState(() {
        _submissionResult = result;
        _isSubmitting = false;
      });

      // Refresh incidents list
      ref.read(incidentsProvider.notifier).fetchIncidents(refresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Incident submitted successfully!'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _showErrorSnackBar(e.userFriendlyMessage);
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _showErrorSnackBar('Unexpected error: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Photo Source',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text('Use camera to capture the incident'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select an existing photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFEA580C);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'Help improve your community',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Report infrastructure & sanitation issues with photos, GPS, and responsible AI suggestions.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),

              // Image picker
              GestureDetector(
                onTap: _isSubmitting ? null : _showImagePickerOptions,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedImage != null
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: _selectedImage != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.file(
                                File(_selectedImage!.path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.greenAccent,
                                  size: 24,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: const Text(
                                  'Tap to change photo',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_enhance_outlined,
                              size: 52,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Capture or Upload Incident Photo',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'JPEG, PNG, WebP (max 5MB)',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // AI Assistance Section
              if (_selectedImage != null && !_skipAi) ...[
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: Color(0xFF38BDF8),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'AI Assistance (Advisory)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                              ],
                            ),
                            if (_isAnalyzingAi)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF38BDF8),
                                ),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: _analyzeWithAi,
                                icon: const Icon(Icons.refresh, size: 14),
                                label: Text(
                                  _aiSuggestion == null
                                      ? 'Analyze Photo'
                                      : 'Re-analyze',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_aiSuggestion != null) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Confidence: ${((_aiSuggestion!['confidence'] ?? 0.8) * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getSeverityColor(
                                    _aiSuggestion!['severity'] ?? 'Medium',
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Suggested Priority: ${_aiSuggestion!['severity'] ?? 'Medium'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getSeverityColor(
                                      _aiSuggestion!['severity'] ?? 'Medium',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _aiSuggestion!['reasoning'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          if (_aiSuggestion!['visual_markers'] is List &&
                              (_aiSuggestion!['visual_markers'] as List).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: (_aiSuggestion!['visual_markers'] as List)
                                  .map(
                                    (marker) => Chip(
                                      label: Text(
                                        marker.toString(),
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
                            'ℹ️ AI suggestions are advisory. You can modify the category and severity below before submitting.',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ] else
                          Text(
                            'Tap "Analyze Photo" to receive AI category, priority, and visual marker recommendations, or fill out the form manually below.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Skip AI Switch (Manual Mode)
              SwitchListTile(
                value: _skipAi,
                onChanged: (val) {
                  setState(() {
                    _skipAi = val;
                  });
                },
                title: const Text(
                  'Submit without AI analysis',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Manual submission bypasses automated AI categorization',
                  style: TextStyle(fontSize: 12),
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 12),

              // Category Selector
              Text(
                'Incident Category',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                    });
                  }
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Severity Selector
              Text(
                'Severity Priority',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _severities.map((sev) {
                  final isSelected = _selectedSeverity == sev;
                  final color = _getSeverityColor(sev);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: Text(
                          sev,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: theme.colorScheme.surface,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedSeverity = sev;
                            });
                          }
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Location card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'GPS Coordinates',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          FilledButton.icon(
                            onPressed: _isFetchingLocation || _isSubmitting
                                ? null
                                : _fetchLocation,
                            icon: _isFetchingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.gps_fixed, size: 16),
                            label: Text(
                              _isFetchingLocation ? 'Fetching...' : 'Get GPS',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      if (_currentPosition != null)
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildCoordinateChip(
                                  'Latitude',
                                  _currentPosition!.latitude.toStringAsFixed(6),
                                ),
                                _buildCoordinateChip(
                                  'Longitude',
                                  _currentPosition!.longitude.toStringAsFixed(6),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    color: Colors.greenAccent, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'GPS Locked',
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else if (_locationError != null)
                        Text(
                          _locationError!,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        )
                      else
                        Text(
                          'Coordinate Lock Required for Submission',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description field
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Describe observations, landmarks, water color, flow rate...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),

              // Submit button
              if (_isSubmitting)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      _skipAi ? 'Submitting report...' : '🤖 Processing report...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recording location & details',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                )
              else
                ElevatedButton.icon(
                  onPressed: _submitReport,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('SUBMIT REPORT'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),

              // Success result
              if (_submissionResult != null) ...[
                const SizedBox(height: 24),
                Card(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.secondary,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Report Submitted!',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Category: ${_submissionResult!['category'] ?? _selectedCategory}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          'Severity: ${_submissionResult!['severity'] ?? _selectedSeverity}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        if (_submissionResult!['status'] != null)
                          Text(
                            'Status: ${_submissionResult!['status']}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoordinateChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
