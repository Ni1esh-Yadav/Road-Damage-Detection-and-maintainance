import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/detection_box.dart';

class ImagePainter extends CustomPainter {
  final ui.Image image;
  final List<DetectionBox> detections;
  final List<String> classLabels;
  final int modelImageWidth;
  final int modelImageHeight;

  ImagePainter(
    this.image,
    this.detections,
    this.classLabels,
    this.modelImageWidth,
    this.modelImageHeight,
  );

  @override
  void paint(Canvas canvas, Size size) {
    Paint boxPaint =
        Paint()
          ..color = Colors.redAccent
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

    Paint textBg =
        Paint()
          ..color = Colors.black.withOpacity(0.6)
          ..style = PaintingStyle.fill;

    canvas.drawImage(image, Offset.zero, Paint());

    final double scaleX = size.width / modelImageWidth;
    final double scaleY = size.height / modelImageHeight;

    for (var det in detections) {
      final bbox = det.bbox;
      final double xMin = bbox[0] * scaleX;
      final double yMin = bbox[1] * scaleY;
      final double xMax = bbox[2] * scaleX;
      final double yMax = bbox[3] * scaleY;

      final rect = Rect.fromLTRB(xMin, yMin, xMax, yMax);
      canvas.drawRect(rect, boxPaint);

      final label =
          "${classLabels[det.classId]} (${(det.confidence * 100).toStringAsFixed(1)}%)";
      final textSpan = TextSpan(
        text: label,
        style: TextStyle(color: Colors.white, fontSize: 14),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final bgRect = Rect.fromLTWH(
        xMin,
        yMin - textPainter.height - 4,
        textPainter.width + 6,
        textPainter.height,
      );
      canvas.drawRect(bgRect, textBg);
      textPainter.paint(
        canvas,
        Offset(xMin + 3, yMin - textPainter.height - 2),
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
