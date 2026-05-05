# SecurePark

## Smart Vehicle QR Assistant

SecurePark is a smart vehicle identification and emergency contact system built using **Flutter** and **Firebase**.

It helps vehicle owners register their vehicles, generate secure QR stickers, and allows others to quickly contact the owner when needed — without exposing unnecessary personal information.

This project is designed as both a practical real-world parking solution and an MCA dissertation/project with SaaS-style scalability.

---

# Live Access

| Platform       | Link                                                                                                                                                               |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 🌐 Web App     | [https://park-13c37.web.app/](https://park-13c37.web.app/)                                                                                                         |
| 📱 Android APK | [https://github.com/kashishub/Secure-Park/releases/download/v1.0/secure-park.apk](https://github.com/kashishub/Secure-Park/releases/download/v1.1/SecurePark.apk) |

---

# Problem Statement

In parking areas, emergencies, accidental blocking, suspicious activity, or urgent communication often require immediate contact with the vehicle owner.

Traditional methods expose personal phone numbers publicly or create unnecessary inconvenience.

SecurePark solves this by using a **QR-based secure contact system**.

Users place a QR sticker on their vehicle, and anyone scanning it can instantly contact the owner safely.

---

# What SecurePark Does

* User Authentication (Register / Login)
* Vehicle Registration and Management
* Unique QR Generation for Every Vehicle
* QR Sticker Download
* QR-Based Contact Flow
* Call Owner Directly
* WhatsApp Quick Contact
* Admin Panel for User & Vehicle Management
* Firebase Cloud Storage and Hosting
* Mobile + Web Access from a Single Codebase

---

# System Flow

### Step 1 — User Registration

User creates an account using email and password.

### Step 2 — Add Vehicle

User enters:

* Vehicle Number
* Contact Number
* Optional WhatsApp Number

### Step 3 — QR Generation

The system generates a unique QR code for that vehicle.

### Step 4 — QR Sticker Placement

User downloads and places the QR sticker on the vehicle.

### Step 5 — Public QR Scan

Anyone scanning the QR gets a secure contact screen where they can:

* Call the owner
* Send WhatsApp message

This ensures fast communication without revealing personal identity publicly.

---

# Main Features

## User Side Features

### Authentication

* Clean Register Screen
* Secure Login System
* Logout Functionality

### Vehicle Management

* Add Vehicle
* View Vehicle List
* Delete Vehicle
* Manage Contact Information

### QR System

* Unique QR Code per Vehicle
* QR Sticker Download
* QR Scanner Screen
* Public Contact Screen

---

## Admin Side Features

### Admin Dashboard

* Total Users
* Active Users
* Blocked Users
* Total Vehicles

### User Management

* Search by Email
* Filter by Role
* Filter by Status
* Pagination Support
* Block / Unblock Users
* Admin Ownership Transfer

### Admin Vehicle Management

Admin also has owner capabilities:

* Add Vehicle
* Delete Vehicle
* Download QR
* Manage Personal Vehicles

---

# Tech Stack

## Frontend

* Flutter
* Dart

## Backend & Cloud

* Firebase Authentication
* Cloud Firestore
* Firebase Hosting

## Deployment

* Android APK Release
* Firebase Web Deployment

---

# UI/UX Highlights

SecurePark is designed with a modern SaaS-style interface.

### Design Features

* Clean Dashboard Layout
* Role-Based User Experience
* Fast and Responsive UI
* Mobile + Web Compatibility
* Practical Real-World Use Case
* Minimal and Professional Design

---

# Installation

# Android APK Installation

### Steps

1. Open APK link above
2. Download the APK file
3. Enable **Install from Unknown Sources** if prompted
4. Install the application
5. Open SecurePark and log in

---

# Web App Access

### Steps

1. Open the web app link above
2. Login or Register
3. Start managing vehicles instantly

---

# Recommended Browsers

## Best Supported Browsers

* Google Chrome
* Mozilla Firefox
* Safari

## Brave Browser Note

If a blank screen appears:

* Disable Shields for this website
* Or use a Private Tab

---

# Project Highlights

## Why This Project Is Strong

* Solves a real-world problem
* Practical parking use case
* Strong MCA dissertation value
* Cloud-based architecture
* Mobile + Web support
* Secure QR workflow
* Admin management system
* Expandable into a SaaS business model

This project is not just academic — it has real product potential.

---

# Upcoming Upgrades

## Vehicle Intelligence Module

Future planned advanced features:

* Vehicle Intelligence Profile
* Challan Status Tracking
* Insurance Status Monitoring
* PUC Expiry Alerts
* FASTag Monitoring
* Dynamic Status Updates
* QR Scan Logging
* Suspicious Scan Detection
* Abuse Detection System
* Device/IP Logging
* Location Tracking (Optional)
* Security Analytics Dashboard

These features will make SecurePark more powerful than a simple QR system.

---

# Author

## Kashish

### Project

SecurePark

### Degree

Master of Computer Applications (MCA)

### Project Type

Dissertation / Major Project

### GitHub

[https://github.com/kashishub/Secure-Park](https://github.com/kashishub/Secure-Park)

---

# License

This project is intended for:

* Personal Use
* Educational Use
* Academic Submission
* MCA Dissertation/Project

For commercial use, please contact the author.

---

# Final Note

SecurePark is built with the vision of combining **security, practicality, and modern SaaS thinking** into a real-world vehicle assistance platform.

It is designed not only to complete an MCA project successfully, but also to demonstrate production-level thinking and scalable product architecture.
