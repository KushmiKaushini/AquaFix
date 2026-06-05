import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/location_provider.dart';
import '../../services/api_service.dart';
import '../../services/api_exceptions.dart';

class IncidentReporterScreen extends ConsumerStatefulWidget {
  const IncidentReporterScreen({super.key});

  @override
  ConsumerState<IncidentReporterScreen> createState() =>
      _IncidentReporterScreenState();
}

class _IncidentReporterScreenState
    extends ConsumerState<IncidentReporterScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  bool _isSubmitting = false;
  Map<String, dynamic>? _verificationResult;
  String? _submissionError;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// Validate form inputs before submission
  String? _validateForm() {
    if (_selectedImage == null) {
      return 'Please capture or upload an incident photo first';
    }

    final locationState = ref.read(locationProvider);
    if (locationState.position == null) {
      return 'GPS coordinates are required. Please tap "Get GPS"';
    }

    final description = _descriptionController.text.trim();
    if (description.length > 1000) {
      return 'Description cannot exceed 1000 characters (currently ${description.length})';
    }

    return null; // Form is valid
  }

  /// Pick image helper
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
          _verificationResult = null;
          _submissionError = null;
        });
      }
    } catch (e) {
      setState(() {
        _submissionError = 'Failed to pick image: ${e.toString()}';
      });
    }
  }

  /// Submit report with retry capability
  Future<void> _submitReport({bool simulate = false}) async {
    // Validate form
    final validationError = _validateForm();
    if (validationError != null) {
      setState(() {
        // Validation error set
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ $validationError'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      if (simulate) {
        // High-fidelity local simulation
        await Future.delayed(const Duration(seconds: 2));
        final locationState = ref.read(locationProvider);
        setState(() {
          _verificationResult = {
            'status': 'Pending',
            'category': 'Pipeline Leak',
            'is_valid': true,
            'description': _descriptionController.text.isNotEmpty
                ? _descriptionController.text
                : 'Active pipeline rupture causing fresh water surge on concrete road.',
            'latitude': locationState.position?.latitude ?? 12.9716,
            'longitude': locationState.position?.longitude ?? 77.5946,
            'confidence': 0.95,
          };
          _isSubmitting = false;
        });
        return;
      }

      // Perform real API upload
      final locationState = ref.read(locationProvider);
      final double lat = locationState.position!.latitude;
      final double lon = locationState.position!.longitude;

      final result = await apiService.submitIncident(
        imagePath: _selectedImage!.path,
        latitude: lat,
        longitude: lon,
        description: _descriptionController.text.trim(),
      );

      setState(() {
        _verificationResult = result;
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Incident submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _submissionError = e.userFriendlyMessage;
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${e.userFriendlyMessage}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _submissionError = 'Unexpected error: ${e.toString()}';
        _isSubmitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Unexpected error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'AquaFix Reporter',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Description
            Text(
              'Report Infrastructure and Sanitation Issues',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Image Picker Box
            GestureDetector(
              onTap: _isSubmitting ? null : () => _showImagePickerOptions(),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
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
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(_selectedImage!.path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.secondary,
                                size: 28,
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
                            size: 60,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Capture or Upload Incident Photo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Supports PNG, JPEG, WebP (max 5MB)',
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

            // Location coordinates card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.tealAccent),
                            SizedBox(width: 8),
                            Text(
                              'Geotag Coordinates',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: locationState.isLoading || _isSubmitting
                              ? null
                              : () => ref
                                  .read(locationProvider.notifier)
                                  .fetchLocation(),
                          icon: locationState.isLoading
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
                            locationState.isLoading ? 'Fetching...' : 'Get GPS',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            backgroundColor: theme.colorScheme.secondary,
                          ),
                        )
                      ],
                    ),
                    const Divider(height: 24),
                    if (locationState.position != null)
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text(
                                'Lat: ${locationState.position!.latitude.toStringAsFixed(6)}',
                              ),
                              Text(
                                'Lon: ${locationState.position!.longitude.toStringAsFixed(6)}',
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
                                'GPS Locked Successfully',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else if (locationState.errorMessage != null)
                      Text(
                        locationState.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
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

            // Description field with validation feedback
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    labelText: 'Add Descriptive Details (Optional)',
                    hintText:
                        'Describe details e.g., "Main pipe burst under public pavement."',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_descriptionController.text.length}/1000 characters',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit buttons
            if (_isSubmitting)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('🤖 Analyzing with Google Gemini...'),
                  Text('Verifying and auto-categorizing incident...'),
                ],
              )
            else ...[
              ElevatedButton.icon(
                onPressed: () => _submitReport(simulate: false),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('SUBMIT REPORT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _submitReport(simulate: true),
                icon: const Icon(Icons.bolt, color: Colors.amber),
                label: const Text('TEST FLOW (AI SIMULATOR)'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.amber),
                  foregroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Error panel with retry option
            if (_submissionError != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.error),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        const Text(
                          'Submission Failed',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _submissionError!,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => _submitReport(simulate: false),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _submissionError = null;
                            });
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Success panel
            if (_verificationResult != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.secondary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.tealAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Verified: ${_verificationResult!['category'] ?? 'Infrastructure Issue'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.tealAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: ${_verificationResult!['status'] ?? 'Pending'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _verificationResult!['description'] ?? 'No description',
                    ),
                    const SizedBox(height: 8),
                    if (_verificationResult!['confidence'] != null)
                      Text(
                        'Confidence: ${((_verificationResult!['confidence'] as num) * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      'Report: (${_verificationResult!['latitude']}, ${_verificationResult!['longitude']})',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Image picker modal
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pick Image from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Capture with Device Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
