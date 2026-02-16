# URJA BUDDY

AI-powered household electricity monitoring with Flutter (iOS/Android/Web) and FastAPI backend.

## Brand Theme
- Primary: #2196F3
- Accent: #00BCD4
- Background: White
- Typography: Rubik

## Structure
```
urja_buddy/
  lib/
  assets/
  backend/
  pubspec.yaml
  firebase.json
```

## Setup
1) Install Flutter 3.x and Dart 3.x.
2) Replace assets/logo.png with your logo.
3) Add Firebase keys to firebase.json and run platform setup via FlutterFire CLI.
4) Run:
```
flutter pub get
flutter run
```

## Backend
```
cd backend
pip install -r requirements.txt
uvicorn server.main:app --reload --port 8000
```

## Build
```
flutter build apk
flutter build web
flutter build ios
```
