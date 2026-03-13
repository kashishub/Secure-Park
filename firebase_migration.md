I have this Python-flask web app (HTML/CSS frontend) currently using PostgreSQL hosted on Render. I want to migrate its database from PostgreSQL to Firebase Firestore so it shares the same database as my Flutter mobile app.

Firebase project: park-13c37
Firestore collections:

users — fields: uid, name, email, phone, role (owner/admin), createdAt
vehicles — fields: userId, vehicleNumber, token (unique string for QR), createdAt
Goal: Replace all PostgreSQL queries with Firebase Admin SDK (Firestore) calls. Auth is handled by Firebase on the Flutter side — the web app just needs to read/write the same Firestore collections.

Please read the project files and help me migrate from PostgreSQL to Firestore.