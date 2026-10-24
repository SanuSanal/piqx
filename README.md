# PiqX

Live football and cricket scores and streams for Android.

- **Football:** Premier League, La Liga, Bundesliga, Serie A, Ligue 1, Champions League, Europa League and Copa del Rey.
- **Cricket:** internationals (Test, ODI, T20I) involving the top ten men's sides, plus the IPL, BBL, PSL, The Hundred, SA20, CPL, ILT20 and MLC.

Scores come from ESPN's public scoreboard feeds (`lib/data/scores_repository.dart`). No API key is needed. The app refreshes every 30 seconds while a match is live and every five minutes otherwise.

## Stream links

The stream page for each sport lives in [`docs/streams.json`](docs/streams.json), which GitHub Pages serves at `https://sanusanal.github.io/piqx/streams.json`:

```json
{
  "football": "https://example.com/football",
  "cricket": null
}
```

The app fetches it on every launch, so changing a link only needs a push to `main`, not a new release. Pages takes a minute or so to deploy. Use `null` while a sport has no stream; the stream screen then shows its placeholder. The app keeps the last links it fetched, so they still work when Pages can't be reached.

## Development

```bash
flutter pub get
flutter test
flutter run
```

## Releases and in-app updates

Pushing a version tag builds signed release APKs and publishes them as a GitHub release (`.github/workflows/release.yml`):

```bash
git tag v1.1.0
git push origin v1.1.0
```

- The tag sets the version: `v1.2.3` becomes version name `1.2.3` and version code `10203`, so tags must keep increasing.
- Tags with a suffix (`v1.3.0-beta.1`) are published as pre-releases, which the in-app updater ignores.
- Each release has one APK per ABI: `piqx-v1.2.3-arm64-v8a.apk` (most phones), `-armeabi-v7a.apk` (older 32-bit phones) and `-x86_64.apk` (emulators). All three share the tag's version code.
- The app checks `releases/latest` on launch (it can be turned off in **App updates**). It downloads the APK for the phone's ABI and hands it to Android's installer.

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
