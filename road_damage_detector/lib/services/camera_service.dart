import 'package:camera/camera.dart';
import 'dart:io';

class CameraService {
  static late List<CameraDescription> _cameras;
  static late CameraDescription _selectedCamera;
  static CameraController?
  _controller; // Make it nullable to handle uninitialized state

  // Initialize the camera
  static Future<void> initialize() async {
    _cameras = await availableCameras();
    _selectedCamera = _cameras.first; // Usually back camera

    // Initialize the camera controller if it has not been initialized
    if (_controller == null) {
      _controller = CameraController(_selectedCamera, ResolutionPreset.high);
      await _controller!.initialize();
    }
  }

  // Get the selected camera description
  static CameraDescription getCamera() {
    return _selectedCamera;
  }

  // Capture an image from the camera
  static Future<File?> captureImage() async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        print('Error: CameraController is not initialized');
        return null;
      }

      final XFile picture = await _controller!.takePicture();
      return File(picture.path); // Return the image as a File
    } catch (e) {
      print('Error capturing image: $e');
      return null; // Handle error by returning null
    }
  }

  // Dispose of the camera controller
  static Future<void> dispose() async {
    if (_controller != null) {
      await _controller!.dispose();
    }
  }
}
