# spark

A quick-thought app.

When you have a sudden idea (a spark), you note it down here, then come back to it later and decide what to do with it. So it is both a notes app and a light reminder app.

This is a pet project of mine.
Current app version: **1.0**.

It still needs polishing, so please do not judge it too harshly yet. I built this primarily for myself.

## Download APK

Release `v1.0`:

`https://github.com/ZadniproIon/spark/releases/tag/v1.0`


## Tech Stack

- Flutter + Dart: Cross-platform UI toolkit and language used to build the app.
- Riverpod: State management for app logic, auth state, and note flows.
- Hive: Fast local database for offline-first note storage on device.
- Supabase: Backend for authentication, cloud sync, and remote note persistence.

## Basic Functionality

- Create and edit text notes quickly.
- Record and save voice notes.
- Move notes to Recycle Bin, restore them, or delete forever.
- Auto-delete notes from Recycle Bin after 30 days.
- Search notes by text.
- Use guest mode (local only) or sign in with Google for sync.
- Download voice notes to Android Downloads.

## Project Setup

```bash
flutter pub get
```

For the best experience:

```bash
flutter run --release
```

If you just want to quickly see how it looks (faster to start, lower performance fidelity):

```bash
flutter run
```

## Screenshots

Screenshots coming soon.

## Disclaimer

This app has only been tested on my own device: **Samsung S24 Ultra**.
I have not tested it on other devices yet, so behavior may vary elsewhere.
