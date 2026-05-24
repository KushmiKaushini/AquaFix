import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/location_provider.dart';
import '../../services/api_service.dart';

class IncidentReporterScreen extends ConsumerStatefulWidget {
  const IncidentReporterScreen({super.key});

  @override
  ConsumerState<IncidentReporterScreen> createState() => _IncidentReporterScreenState();
}

class _IncidentReporterScreenState extends ConsumerState<IncidentReporterScreen> {
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

  // Pick image helper
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Dynamic high quality compression
        maxWidth: 1080,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _verificationResult = null; // Reset previous runs
          _submissionError = null;
        });
      }
    } catch (e) {
      setState(() {
        _submissionError = "Camera Picker failed: ${e.toString()}";
      });
    }
  }

  // Trigger submission to Backend Gateway
  Future<void> _submitReport({bool simulate = false}) async {
    final locationState = ref.read(locationProvider);
    
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please capture or upload an incident photo first!')),
      );
      return;
    }

    if (locationState.position == null && !simulate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📍 Geotagging is required. Please capture your coordinates.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
      _verificationResult = null;
    });

    try {
      if (simulate) {
        // High-fidelity local simulation to run immediately out-of-the-box
        await Future.delayed(const Duration(seconds: 2));
        setState(() {
          _verificationResult = {
            "status": "Pending",
            "category": "Pipeline Leak",
            "is_valid": true,
            "description": _descriptionController.text.isNotEmpty 
                ? _descriptionController.text 
                : "Active pipeline rupture causing fresh water surge on concrete road.",
            "latitude": locationState.position?.latitude ?? 12.9716,
            "longitude": locationState.position?.longitude ?? 77.5946
          };
          _isSubmitting = false;
        });
        return;
      }

      // Perform real API upload to FastAPI
      final double lat = locationState.position!.latitude;
      final double lon = locationState.position!.longitude;
      
      final result = await apiService.submitIncident(
        imagePath: _selectedImage!.path,
        latitude: lat,
        longitude: lon,
        description: _descriptionController.text,
      );

      setState(() {
        _verificationResult = result;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _submissionError = e.toString().replaceAll("Exception: ", "");
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('AquaFix Reporter', style: TextStyle(fontWeight: FontWeight.w700)),
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

            // Image Picker Box - Camera / Gallery Ingest
            GestureDetector(
              onTap: () {
                _showImagePickerOptions();
              },
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedImage != null 
                        ? theme.colorScheme.secondary 
                        : theme.colorScheme.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(_selectedImage!.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Supports PNG, JPEG under 2MB',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Location coordinates capture component
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
                            Text('Geotag Coordinates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: locationState.isLoading 
                              ? null 
                              : () => ref.read(locationProvider.notifier).fetchLocation(),
                          icon: locationState.isLoading 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.gps_fixed, size: 16),
                          label: Text(locationState.isLoading ? 'Fetching...' : 'Get GPS'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              Text('Latitude: ${locationState.position!.latitude.toStringAsFixed(6)}'),
                              Text('Longitude: ${locationState.position!.longitude.toStringAsFixed(6)}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 16),
                              SizedBox(width: 4),
                              Text('GPS Locked Successfully', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
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
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Context Input Field
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Add Descriptive Details (Optional)',
                hintText: 'Describe details e.g., "Main pipe burst under public pavement near park entrance."',
                alignLabelWithHint: true,
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Buttons (Live and Simulator Toggles)
            if (_isSubmitting)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('🤖 Analyzing with Google Gemini 1.5 Flash...'),
                  Text('Verifying spam filtering & auto-categorization...'),
                ],
              )
            else ...[
              ElevatedButton.icon(
                onPressed: () => _submitReport(simulate: false),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('SUBMIT REPORT TO BACKEND'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _submitReport(simulate: true),
                icon: const Icon(Icons.bolt, color: Colors.amber),
                label: const Text('TEST E2E FLOW (AI SIMULATOR)'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.amber),
                  foregroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
            
            const SizedBox(height: 24),

            // Display Results and Validation Error Panels
            if (_submissionError != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
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
                        const Text('Submission Refused', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_submissionError!, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),

            if (_verificationResult != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.secondary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.tealAccent),
                        const SizedBox(width: 8),
                        Text(
                          'Verified: ${_verificationResult!['category']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.tealAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Status: ${_verificationResult!['status'] ?? 'Pending'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Verifying Reason: ${_verificationResult!['description']}'),
                    const SizedBox(height: 8),
                    Text(
                      'Report logged at coordinate (${_verificationResult!['latitude']}, ${_verificationResult!['longitude']})',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Modal selector for Gallery / Camera choice
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
