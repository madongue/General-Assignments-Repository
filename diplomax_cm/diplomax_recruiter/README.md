# Diplomax CM Recruiter App

Flutter recruiter portal for diploma verification and recruiter account management.

## Current Scope

- Recruiter login
- Recruiter self-registration flow
- Dashboard and scanner flow
- Verification result screens and status handling
- Subscription screen and plan gating hooks

Business model currently implemented in platform logic:

- Free plan: up to 5 verifications per month
- Paid plan: unlimited verification and certified PDF export

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

Web run example:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/v1
```

## Build APK

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.diplomax.cm/v1
```

## Notes

- Router and main UI flow are defined in `lib/main.dart`.
- If API connectivity fails, sign-in and verification requests will fail.
