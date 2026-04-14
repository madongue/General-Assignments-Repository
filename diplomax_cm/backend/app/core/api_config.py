"""
Diplomax CM — Shared API base URL configuration for Flutter apps.

LOCAL TESTING (Android emulator)  → http://10.0.2.2:8000/v1
LOCAL TESTING (iOS simulator)     → http://localhost:8000/v1
LOCAL TESTING (Physical device)   → http://YOUR_LOCAL_IP:8000/v1
PRODUCTION                        → https://api.diplomax.cm/v1

How to set this in Flutter:
  Add to your run configuration in Android Studio:
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/v1

  Or set it in your launch.json / run args when using VS Code.
"""

FLUTTER_LOCAL_ANDROID  = "http://10.0.2.2:8000/v1"
FLUTTER_LOCAL_IOS      = "http://localhost:8000/v1"
FLUTTER_PRODUCTION     = "https://api.diplomax.cm/v1"
