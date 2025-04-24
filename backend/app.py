from flask import Flask, request, jsonify
from ultralytics import YOLO
from flask_cors import CORS
from PIL import Image
import numpy as np
import cv2
import os
from pymongo import MongoClient
import datetime
from bson import ObjectId  


app = Flask(__name__)
CORS(app)

model = YOLO("models/YOLOv8_Small_RDD.pt")
client = MongoClient("mongodb://localhost:27017/road_maintainance")
db = client["road_damage"]
complaints_col = db["complaints"]

UPLOAD_FOLDER = 'uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

@app.route("/predict-image", methods=["POST"])
def predict_image():
    if "image" not in request.files:
        return jsonify({"error": "No image uploaded"}), 400

    file = request.files["image"]
    image = Image.open(file.stream).convert("RGB")
    np_img = np.array(image)
    resized = cv2.resize(np_img, (640, 640))

    results = model.predict(resized, conf=0.2)
    detections = []
    for result in results:
        for box in result.boxes:
            x1, y1, x2, y2 = map(int, box.xyxy[0])
            cls = int(box.cls)
            conf = float(box.conf)
            label = f"{cls} ({conf:.2f})"

            cv2.rectangle(resized, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.putText(resized, label, (x1, y1 - 10),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
            
            detections.append({
                'class_id': int(box.cls),
                'confidence': float(box.conf),
                'bbox': box.xyxy[0].tolist()
            })

    # Save the image
    filename = f"{datetime.datetime.now().timestamp()}.jpg"
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    cv2.imwrite(filepath, cv2.cvtColor(resized, cv2.COLOR_RGB2BGR))

    height, width = resized.shape[:2]
    image_path = f"{UPLOAD_FOLDER}/{filename}"
    return jsonify({
        "detections": detections,
        "image_width": width,
        "image_height": height,
        "image_path": image_path
    })

@app.route("/submit-complaint", methods=["POST"])
def submit_complaint():
    data = request.json
    if not data or "name" not in data or "phone" not in data or "location" not in data:
        return jsonify({"error": "Invalid complaint data"}), 400
    if not data["detections"]:
        return jsonify({"error": "No detections found"}), 400
    if not data["name"] or not data["phone"] or not data["location"]:
        return jsonify({"error": "Name, phone, and location are required"}), 400
    if not data["phone"].isdigit() or len(data["phone"]) != 10:
        return jsonify({"error": "Invalid phone number"}), 400
    if not data["location"]:
        return jsonify({"error": "Location is required"}), 400

    complaint = {
        "name": data["name"],
        "phone": data["phone"],
        "location": data["location"],
        "image_path": data["image_path"],
        "detections": data["detections"],
        "status": "pending",
        "assigned_to": None,
        "created_at": datetime.datetime.now()
    }
    print("DETECTIONS:", data["detections"])
    complaints_col.insert_one(complaint)
    return jsonify({"message": "Complaint submitted!"})

@app.route("/admin/complaints", methods=["GET"])
def get_all_complaints():
    complaints = list(complaints_col.find())
    for comp in complaints:
        comp["_id"] = str(comp["_id"])
    return jsonify(complaints)

@app.route("/admin/assign", methods=["POST"])
def assign_complaint():
    data = request.json
    complaints_col.update_one(
        {"_id": ObjectId(data["complaint_id"])},
        {"$set": {"assigned_to": data["engineer"], "status": "assigned"}}
    )
    return jsonify({"message": "Complaint assigned."})

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
