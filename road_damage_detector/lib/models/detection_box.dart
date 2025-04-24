class DetectionBox {
  final int classId;
  final double confidence;
  final List<double> bbox;

  DetectionBox({
    required this.classId,
    required this.confidence,
    required this.bbox,
  });

  factory DetectionBox.fromJson(Map<String, dynamic> json) {
    return DetectionBox(
      classId: json['class_id'],
      confidence: json['confidence'],
      bbox: List<double>.from(json['bbox']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'class_id': classId, 'confidence': confidence, 'bbox': bbox};
  }
}
