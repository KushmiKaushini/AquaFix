import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  // 10.0.2.2 is Android Emulator's proxy alias to host's localhost (127.0.0.1)
  // For iOS emulator or general local device mapping, override with host IP.
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

  Future<Map<String, dynamic>> submitIncident({
    required String imagePath,
    required double latitude,
    required double longitude,
    required String description,
  }) async {
    final uri = Uri.parse('$baseUrl/incidents/report');
    
    // Construct standard multipart/form-data upload request
    final request = http.MultipartRequest('POST', uri);

    // Attach geolocation coordinates & user context notes
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();
    request.fields['description'] = description;

    // Open image file and parse format type
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception("Selected image file does not exist at local path: $imagePath");
    }

    final String fileExtension = file.path.split('.').last.toLowerCase();
    final String mimeSubtype = (fileExtension == 'png') ? 'png' : 'jpeg';

    final multipartFile = await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: MediaType('image', mimeSubtype),
    );
    
    request.files.add(multipartFile);

    // Send payload
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      // Decode potential JSON error payload from backend (like spam rejection)
      try {
        final errorJson = json.decode(response.body);
        final String errorMessage = errorJson['detail'] ?? 'Ingestion failed with status code ${response.statusCode}';
        throw Exception(errorMessage);
      } catch (_) {
        throw Exception('API Server error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    }
  }
}

final apiService = ApiService();
