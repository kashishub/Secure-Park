# 🚗 SecurePark ID – Vehicle Contact System

SecurePark ID is a web-based Vehicle Contact System that allows vehicle owners to generate a QR code sticker for their vehicle. 

In case of emergency, blocking, or parking issues, anyone can scan the QR code and directly contact the vehicle owner via Call, WhatsApp, or SMS — without publicly displaying the owner's number on the vehicle.

---
## Update Log

### 23 Feb 2026
- Database tables "users" and "vehicles" truncated.
- System reset to fresh state.
- All data cleared.
- Application now behaves like first-time deployment.

---
## 🌐 Live Demo

🔗 Live Application:  
https://secure-park.onrender.com

🔗 GitHub Repository:  
https://github.com/kashishub/Secure-Park

sha256:8c2bbbc44181e85f8e9c9eca0dec7cd9581045d46466eac699b8ac0b76eb2270

---

## 📌 Problem Statement

Many vehicles get blocked in parking areas, residential complexes, or public spaces. Displaying phone numbers publicly is unsafe and compromises privacy.

SecurePark ID solves this by:
- Generating a QR-based contact system
- Protecting the owner's number from being visibly displayed
- Allowing controlled communication when needed

---

## ✨ Features

### ✅ Vehicle Registration
- Register vehicle number
- Add call number
- Add optional WhatsApp number
- Automatic fallback if WhatsApp number not provided

### ✅ Smart Validation Logic
Case 1:
- Same Vehicle + Same Phone → "Vehicle already registered."

Case 2:
- Same Vehicle + Different Phone → "Vehicle already registered with a different number."

Case 3:
- New Vehicle → Insert into database

### ✅ QR Code Generation
- Unique token-based QR link
- Secure vehicle lookup
- Dynamic routing

### ✅ Premium 3x5 Sticker Design
- Rounded QR container
- Watermark background text
- Emergency warning section
- Print-ready layout

### ✅ Contact Options
After scanning:
- Direct Call
- WhatsApp message
- SMS option

---

## 🛠️ Tech Stack

- Python 3
- Flask
- SQLite (temporary storage)
- Gunicorn (Production server)
- HTML5 / CSS3
- QRCode Library
- Render (Cloud Hosting)

---

## 📂 Project Structure
Secure-Park/
│
├── app.py
├── requirements.txt
├── Procfile
├── README.md
│
├── templates/
│ ├── register.html
│ ├── qr_result.html
│ └── contact.html
│
└── static/
├── style.css
└── qrcodes/

---

