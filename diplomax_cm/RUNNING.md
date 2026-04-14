# Diplomax CM — How to Run

## Step 1 — Start the backend

```bash
cd diplomax_cm/backend

# Copy .env template and fill in your values
cp .env.example .env

# Start all 5 services (PostgreSQL, Redis, FastAPI, Celery, Nginx)
docker compose up -d

# Check it is running
curl http://localhost:8000/healthz
```

## Step 2 — Run a Flutter app

### Student app

Open `diplomax_cm/diplomax_student/` in Android Studio.

In Android Studio: Run → Edit Configurations → add to Additional run args:

```bash
--dart-define=API_BASE_URL=http://10.0.2.2:8000/v1
```

(Use `http://localhost:8000/v1` for iOS simulator, or your machine's LAN IP for a physical device)

Then click Run (green play button).

### University app

Open `diplomax_cm/diplomax_university/` in Android Studio. Same dart-define.

### Recruiter app (web)

Open `diplomax_cm/diplomax_recruiter/` in Android Studio.
Select Chrome as the run target. Same dart-define.

## Step 3 — First login

The bootstrap passwords are read from backend environment variables (set in `.env`).

| App | Email / Matricule | Password source |
| --- | --- | --- |
| Student | ICTU20223180 | `DEFAULT_STUDENT_PASSWORD` |
| University | `admin@ictuniversity.cm` | `DEFAULT_ICT_ADMIN_PASSWORD` |
| Recruiter | (create via admin panel) | — |

## Minimum requirements

- Flutter 3.22+ (`flutter --version`)
- Dart 3.3+
- Android Studio Hedgehog or newer
- Docker Desktop (for the backend)
- Android device or emulator running API 23+ (Android 6.0)
- iOS 13+ for iPhone/iPad

## Connecting a physical Android phone

1. Enable Developer Options on the phone
2. Enable USB Debugging
3. Connect via USB
4. In Android Studio, select your device from the device dropdown
5. Use `http://YOUR_LAPTOP_LAN_IP:8000/v1` as the API URL (e.g. `http://192.168.1.5:8000/v1`)
