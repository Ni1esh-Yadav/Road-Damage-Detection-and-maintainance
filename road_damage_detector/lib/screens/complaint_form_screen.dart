import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/detection_box.dart';
import '../widgets/image_painter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ComplaintFormScreen extends StatefulWidget {
  final File image;
  final List<Map<String, dynamic>> detections;
  final String imagePath;

  const ComplaintFormScreen({
    required this.image,
    required this.detections,
    required this.imagePath,
  });

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  ui.Image? _uiImage;
  late List<DetectionBox> _detectionBoxes;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();

  final classes = [
    "Longitudinal Crack",
    "Transverse Crack",
    "Alligator Crack",
    "Potholes",
  ];

  @override
  void initState() {
    super.initState();
    _detectionBoxes =
        widget.detections.map((d) => DetectionBox.fromJson(d)).toList();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.image.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _uiImage = frame.image;
    });
  }

  Future<void> _submitComplaint() async {
    final url = Uri.parse('http://192.168.1.7:5000/submit-complaint');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'location': _locationController.text,
        'detections': widget.detections,
        'image_path': widget.imagePath,
      }),
    );
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complaint submitted successfully!')),
      );
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text('Success'),
              content: Text('Complaint has been submitted!'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context); // go back to HomePage
                  },
                  child: Text('OK'),
                ),
              ],
            ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submission failed!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Submit Complaint')),
      body:
          _uiImage == null
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    FittedBox(
                      child: SizedBox(
                        width: _uiImage!.width.toDouble(),
                        height: _uiImage!.height.toDouble(),
                        child: CustomPaint(
                          painter: ImagePainter(
                            _uiImage!,
                            _detectionBoxes,
                            classes,
                            640,
                            640,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(labelText: 'Name'),
                            validator:
                                (val) => val!.isEmpty ? 'Required' : null,
                          ),
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(labelText: 'Phone'),
                            keyboardType: TextInputType.phone,
                            validator:
                                (val) => val!.isEmpty ? 'Required' : null,
                          ),
                          TextFormField(
                            controller: _locationController,
                            decoration: InputDecoration(labelText: 'Location'),
                            validator:
                                (val) => val!.isEmpty ? 'Required' : null,
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                _submitComplaint();
                              }
                            },
                            child: Text('Submit Complaint'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
