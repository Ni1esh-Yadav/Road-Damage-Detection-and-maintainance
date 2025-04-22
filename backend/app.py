from flask import Flask, request, jsonify
from ultralytics import YOLO
import numpy as np
import cv2
from PIL import Image
import io
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  

model = YOLO("models/YOLOv8_Small_RDD.pt")

@app.route('/predict-image', methods=['POST'])
def predict_image():
    if 'image' not in request.files:
        return jsonify({'error': 'No image uploaded'}), 400

    file = request.files['image']
    image = Image.open(file.stream).convert("RGB")
    np_img = np.array(image)
    resized = cv2.resize(np_img, (640, 640))

    results = model.predict(resized, conf=0.1)
    detections = []

    # print("Raw prediction:", results)
    for result in results:
        # print("Boxes:", result.boxes)
        # print("Classes:", result.boxes.cls)
        # print("Confidences:", result.boxes.conf)
        # print("Coordinates:", result.boxes.xyxy)
        for box in result.boxes:
            detections.append({
                'class_id': int(box.cls),
                'confidence': float(box.conf),
                'bbox': box.xyxy[0].tolist()
            })
    # print(result.boxes.xyxy)
    # print(result.boxes.conf)
    # print(result.boxes.cls)
    annotated = results[0].plot()
    cv2.imwrite("output.png", annotated)

    height, width = resized.shape[:2]
    return jsonify({
    'detections': detections,
    'image_width': width,
    'image_height': height
    })


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
