# Playwright MVP - Diplomax Backend

Minimal backend smoke tests aligned with the 3 apps:
- Student auth endpoint
- University auth endpoint
- Recruiter register/login endpoints
- Health endpoint

## 1) Install

```powershell
Set-Location "C:\Users\Nguend Arthur Johann\Desktop\General-Assignments-Repository\diplomax_cm\playwright-mvp"
npm install
```

## 2) Configure env

Copy `.env.example` values into your shell (or set directly):

```powershell
$env:API_BASE_URL="https://diplomax-backend.onrender.com"
$env:STUDENT_PASSWORD="<DEFAULT_STUDENT_PASSWORD>"
$env:UNIVERSITY_PASSWORD="<DEFAULT_ICT_ADMIN_PASSWORD>"
```

## 3) Run tests

```powershell
npm test
```

## Notes
- `API_BASE_URL` must NOT include `/v1`.
- Student/University positive login tests are skipped if passwords are not set.
- Recruiter register allows 200 or 409 (already registered).
