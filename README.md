# PiqX

Live football and cricket scores and streams for Android.

- **Football:** Premier League, La Liga, Bundesliga, Serie A, Ligue 1, Champions League, Europa League and Copa del Rey.
- **Cricket:** internationals (Test, ODI, T20I) involving the top ten men's sides, plus the IPL, BBL, PSL, The Hundred, SA20, CPL, ILT20 and MLC.

Scores come from ESPN's public scoreboard feeds (`lib/data/scores_repository.dart`). No API key is needed. The app refreshes every 30 seconds while a match is live and every five minutes otherwise.

## Development

```bash
flutter pub get
flutter test
flutter run
```

## Releases and in-app updates

Pushing a version tag builds a signed release APK and publishes it as a GitHub release (`.github/workflows/release.yml`):

```bash
git tag v1.1.0
git push origin v1.1.0
```

- The tag sets the version: `v1.2.3` becomes version name `1.2.3` and version code `10203`, so tags must keep increasing.
- Tags with a suffix (`v1.3.0-beta.1`) are published as pre-releases, which the in-app updater ignores.
- The app checks `releases/latest` on launch (it can be turned off in **App updates**). It downloads the APK and hands it to Android's installer.

### Signing

Every release must be signed with the same key, or installed copies can't update to it. The workflow reads these repository secrets:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | The release keystore (`.jks`), base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |

For local release builds, put the same values in `android/key.properties`, with `storeFile` pointing at the keystore. That file and all keystores are git-ignored. Without them, release builds fall back to the debug key.

## Branding

Logo masters, app icons and usage guidelines live in `branding/kit/`. The landing page is in `docs/`.
