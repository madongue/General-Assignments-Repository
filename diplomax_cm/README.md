# Diplomax CM Monorepo

Diplomax CM is a multi-app platform for secure academic credential issuance, storage, and verification.

## Folder Structure

- `backend/`: FastAPI backend, Redis, PostgreSQL, Celery worker
- `diplomax_student/`: student Flutter app
- `diplomax_university/`: university/admin Flutter app
- `diplomax_recruiter/`: recruiter Flutter app
- `scripts/`: PowerShell test runners for backend and apps
- `RUNNING.md`: local run instructions
- `CI-CD.md`: CI/CD and release workflow guidance

## Current Deployment/Build Direction

- Source control and automation are centered on GitHub.
- APK build and release automation is handled by workflows in `.github/workflows`.
- Student, university, and recruiter APKs are built in CI and published on tag releases.

## API Base URL Strategy

- App default: `https://api.diplomax.cm/v1`
- Local/staging override supported via:

```bash
--dart-define=API_BASE_URL=http://10.0.2.2:8000/v1
```

## Quick Start

1. Start backend by following `RUNNING.md`.
2. Run one app (`diplomax_student`, `diplomax_university`, or `diplomax_recruiter`) with `flutter run` and optional API override.
3. Use `scripts/test_all.ps1` for a full local validation pass.
