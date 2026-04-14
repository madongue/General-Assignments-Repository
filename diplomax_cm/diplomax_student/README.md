# Diplomax CM Student App

Flutter mobile client for students to access and verify academic credentials in Diplomax CM.

## Current Scope

- Student authentication flow (login, first login, biometric entry)
- Credential vault and document details
- QR generation and QR scanning
- NFC verification flow
- OCR and liveness flows
- Document sharing and international share
- Document request flow
- Payment screen integration
- Profile and home dashboard navigation

## API Configuration

Default production API:

`https://api.diplomax.cm/v1`

Override for local or staging:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/v1
```

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Build APK

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.diplomax.cm/v1
```

## Notes

- App routes are defined in `lib/main.dart`.
- If backend is not reachable, login and API-backed features will fail.
- For full monorepo setup, follow `../RUNNING.md`.
