# Vault

A personal, offline-first credential manager for Android, built with Flutter.
Logins, bank cards and ID documents are stored encrypted on the device
(AES-256-GCM), unlocked by fingerprint with a 6-digit PIN fallback.

See [REQUIREMENTS.md](REQUIREMENTS.md) for the full spec and design decisions.

## Build

```
flutter pub get
flutter build apk --release --target-platform android-arm64
```

Output: `build/app/outputs/flutter-apk/app-release.apk`. Without
`android/key.properties` the build falls back to debug signing.

## Notes

- The encryption is standard (AES-256-GCM, PBKDF2-HMAC-SHA256) but has not been
  independently audited. Use at your own risk, and build it yourself rather than
  installing an APK from someone you don't know.
- Fonts: IBM Plex Sans and Mono, under the SIL Open Font License
  (`assets/fonts/OFL.txt`).
- To make your own build, change the application id in
  `android/app/build.gradle.kts` and create your own signing key.

Licensed under the MIT License, see [LICENSE](LICENSE).
