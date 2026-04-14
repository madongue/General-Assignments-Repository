# Diplomax CM University App

Flutter app for institution and university administration in Diplomax CM.

## Current Scope

- University/admin login
- Institution onboarding registration flow (`/register`)
- Dashboard and ministry views
- Student management and student details
- Document listing and detail views
- Document issuance workflows:
  - Manual form
  - PDF scan
  - CSV import
  - Photo scan
  - Template fill
  - Batch signing
- Request review and pricing management flows

## API Configuration

Default production API:

`https://api.diplomax.cm/v1`

Override for local/staging:

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

- Main route map and shell navigation are in `lib/main.dart`.
- For backend startup and first-login bootstrap users, use `../RUNNING.md`.
