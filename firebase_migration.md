# Firebase Migration Notes (Completed)

This project is now migrated from PostgreSQL to Firebase Auth + Firestore so both web and Flutter use the same account identity and data.

## Firebase Project

- Project ID: `park-13c37`

## Required Environment Variables

- `FIREBASE_WEB_API_KEY`: Web API key from Firebase project settings (used for email/password sign-in from Flask).
- One of the following credentials options for Firebase Admin SDK:
	- `GOOGLE_APPLICATION_CREDENTIALS` = absolute path to service account JSON file, OR
	- `FIREBASE_CREDENTIALS_JSON` = full service account JSON string.
- `SECRET_KEY`: Flask session secret.

## Shared Data Model

### `users` collection (document id = Firebase Auth `uid`)

- `uid` (string)
- `name` (string)
- `email` (string, lowercase)
- `phone` (string)
- `role` (`owner` or `admin`)
- `isBlocked` (boolean)
- `createdAt` (timestamp)

### `vehicles` collection

- `userId` (string, user `uid`)
- `vehicleNumber` (string)
- `callNumber` (string)
- `whatsappNumber` (string)
- `token` (string, unique QR token)
- `createdAt` (timestamp)

## Account Compatibility Behavior

- Flutter app authenticates with Firebase Auth directly.
- Web app authenticates against Firebase Auth using Identity Toolkit API.
- Both apps use the same `uid` and same Firestore user document.
- User can login from either web or Flutter using the same credentials.

## Notes

- Legacy PostgreSQL fields (`password`, numeric user ids, SQL joins) are removed.
- Admin and owner features now read/write Firestore documents.