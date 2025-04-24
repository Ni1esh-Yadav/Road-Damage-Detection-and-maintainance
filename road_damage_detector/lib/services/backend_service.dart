import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/detection_box.dart';

class BackendService {
  static Future<Map<String, dynamic>?> sendToBackend(File imageFile) async {
    final uri = Uri.parse("http://192.168.1.7:5000/predict-image");
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      final jsonResp = jsonDecode(await response.stream.bytesToString());

      final List<DetectionBox> detections =
          (jsonResp['detections'] as List)
              .map((d) => DetectionBox.fromJson(d))
              .toList();

      return {
        'detections': detections,
        'width': jsonResp['image_width'],
        'height': jsonResp['image_height'],
        'image_path': jsonResp['image_path'],
      };
    } else {
      print("Error from backend");
      return null;
    }
  }
}
