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
import random
from werkzeug.security import generate_password_hash, check_password_hash
from twilio.rest import Client

app = Flask(__name__)
CORS(app)
from dotenv import load_dotenv
load_dotenv()


TWILIO_ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID', 'your_sid_here')
TWILIO_AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN', 'your_auth_token')
TWILIO_PHONE_NUMBER = os.getenv('TWILIO_PHONE_NUMBER', '+1234567890')

twilio_client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)

model = YOLO("models/YOLOv8_Small_RDD.pt")
client = MongoClient("mongodb://localhost:27017/road_maintainance")
db = client["road_damage"]
complaints_col = db["complaints"]
users_col = db["users"]
otps_col = db["otps"]

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

@app.route("/send-otp", methods=["POST"])
def send_otp():
    data = request.json
    phone = data.get("phone")

    if not phone or not phone.isdigit() or len(phone) != 10:
        return jsonify({"error": "Invalid phone number"}), 400

    full_phone = "+91" + phone  # Add country code if you're in India

    otp = str(random.randint(100000, 999999))
    expiry = datetime.datetime.now() + datetime.timedelta(minutes=5)

    # Store OTP in DB (your MongoDB logic)
    otps_col.update_one(
        {"phone": phone},
        {
            "$set": {
                "otp": otp,
                "expires_at": expiry,
                "verified": False  # Optionally track if it's used
            }
        },
        upsert=True
    )

    try:
        message = twilio_client.messages.create(
            body=f"Your OTP is {otp}. It expires in 5 minutes.",
            from_=TWILIO_PHONE_NUMBER,
            to=full_phone
        )
        return jsonify({"message": "OTP sent successfully"})
    except Exception as e:
        return jsonify({"error": "Failed to send OTP", "details": str(e)}), 500

@app.route("/verify-otp", methods=["POST"])
def verify_otp():
    data = request.json
    phone = data.get("phone")
    otp = data.get("otp")

    record = otps_col.find_one({"phone": phone})
    if not record or record["otp"] != otp or datetime.datetime.now() > record["expires_at"]:
        return jsonify({"error": "Invalid or expired OTP"}), 400

    user = users_col.find_one({"phone": phone})
    if not user:
        # New user registration
        user = {
            "phone": phone,
            "role": "user",
            "created_at": datetime.datetime.now()
        }
        users_col.insert_one(user)

    user_data = users_col.find_one({"phone": phone})
    return jsonify({
        "message": "Login successful",
        "user": {
            "id": str(user_data["_id"]),
            "role": user_data["role"]
        }
    })


@app.route("/create-admin", methods=["POST"])
def create_admin():
    data = request.json
    email = data.get("email")
    password = data.get("password")
    role = data.get("role")

    if not email or not password or role not in ["admin", "engineer"]:
        return jsonify({"error": "Invalid data"}), 400

    hashed_pw = generate_password_hash(password)
    users_col.insert_one({
        "email": email,
        "password": hashed_pw,
        "role": role,
        "created_at": datetime.datetime.now()
    })

    return jsonify({"message": f"{role.capitalize()} created"})

@app.route("/login", methods=["POST"])
def login():
    data = request.json
    email = data.get("email")
    password = data.get("password")

    user = users_col.find_one({"email": email})
    if not user or not check_password_hash(user["password"], password):
        return jsonify({"error": "Invalid credentials"}), 401

    return jsonify({
        "message": "Login successful",
        "user": {
            "id": str(user["_id"]),
            "role": user["role"]
        }
    })

@app.route("/engineer/update-status", methods=["POST"])
def update_status():
    data = request.json
    complaint_id = data.get("complaint_id")
    new_status = data.get("status")

    if not complaint_id or new_status not in ["completed", "in-progress"]:
        return jsonify({"error": "Invalid request"}), 400

    complaints_col.update_one(
        {"_id": ObjectId(complaint_id)},
        {"$set": {"status": new_status}}
    )
    return jsonify({"message": f"Status updated to {new_status}."})




if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
