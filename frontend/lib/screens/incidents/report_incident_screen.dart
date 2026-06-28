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
  String? _locationError;
  Map<String, dynamic>? _submissionResult;

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
                'Report infrastructure and sanitation issues with photos and location data',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),

              // Image picker
              GestureDetector(
                onTap: _isSubmitting ? null : _showImagePickerOptions,
                child: Container(
                  height: 220,
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
                                  'Tap to change',
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
                              size: 56,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Capture or Upload Photo',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to select • JPEG, PNG, WebP (max 5MB)',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

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
                  hintText: 'Describe the incident details, severity, and any relevant information...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              if (_isSubmitting)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      '🤖 Analyzing with AI...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verifying and categorizing incident',
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
                          'Category: ${_submissionResult!['category'] ?? 'Analyzing...'}',
                          style: theme.textTheme.bodyMedium,
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
