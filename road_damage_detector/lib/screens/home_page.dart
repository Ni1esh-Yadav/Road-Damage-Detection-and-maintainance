import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:road_damage_detector/screens/complaint_form_screen.dart';
import 'package:road_damage_detector/services/camera_capture_screen.dart';
import '../models/detection_box.dart';
import '../services/backend_service.dart';
import '../widgets/image_painter.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  ui.Image? _uiImage;
  List<DetectionBox> _detections = [];
  int _modelImageWidth = 640;
  int _modelImageHeight = 640;
  String? _backendImagePath;

  final List<String> classes = [
    "Longitudinal Crack",
    "Transverse Crack",
    "Alligator Crack",
    "Potholes",
  ];

  Future<void> pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      await _processImage(imageFile);
    }
  }

  Future<void> captureFromCamera() async {
    final imageFile = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder:
            (_) => CameraCaptureScreen(
              onImageCaptured: (file) {
                Navigator.pop(context, file);
              },
            ),
      ),
    );

    if (imageFile != null) {
      await _processImage(imageFile);
    }
  }

  Future<void> _processImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    setState(() {
      _image = imageFile;
      _uiImage = frame.image;
      _detections.clear();
    });

    final result = await BackendService.sendToBackend(imageFile);
    if (result != null) {
      setState(() {
        _detections = result['detections'];
        _modelImageWidth = result['width'];
        _modelImageHeight = result['height'];
        _backendImagePath = result['image_path'];
        print(
          "Image path from backend:inside homepage on 76 $_backendImagePath",
        );
      });
    }
  }

  void _openComplaintForm() {
    if (_image != null && _detections.isNotEmpty && _backendImagePath != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => ComplaintFormScreen(
                image: _image!,
                detections: _detections.map((d) => d.toJson()).toList(),
                imagePath: _backendImagePath!,
              ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No valid image or detections to submit")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Road Damage Detector")),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: pickFromGallery,
                  child: Text("Pick from Gallery"),
                ),
                ElevatedButton(
                  onPressed: captureFromCamera,
                  child: Text("Capture from Camera"),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (_uiImage != null)
              Expanded(
                child: FittedBox(
                  child: SizedBox(
                    width: _uiImage!.width.toDouble(),
                    height: _uiImage!.height.toDouble(),
                    child: CustomPaint(
                      painter: ImagePainter(
                        _uiImage!,
                        _detections,
                        classes,
                        _modelImageWidth,
                        _modelImageHeight,
                      ),
                    ),
                  ),
                ),
              ),
            if (_uiImage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: ElevatedButton(
                  onPressed: _openComplaintForm,
                  child: Text("Submit Complaint"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
