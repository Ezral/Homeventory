# Homeventory Flutter client

Android-first Flutter app for collaborative household inventory.

```text
Home → Room → Furniture / Storage → Container → Nested container → Item
```

## Prerequisites

- Flutter 3.22+ (stable)
- A Supabase project with migrations from `../supabase/migrations` applied
- Google OAuth client configured in Supabase Auth
- For native Android Google Sign-In: Web client ID as `GOOGLE_WEB_CLIENT_ID`

## Run

From `mobile/`:

```bash
flutter pub get

flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Never put the Supabase **service-role** key in the app.

## What’s implemented (Phase 1–3 client)

- Google SSO (native ID token + OAuth fallback)
- Profile load (created by `handle_new_user` trigger)
- Secure local active-home preference; cleared on logout
- Homes: list, create, archive-ready model, invite create/accept (token or short code)
- Members: list, remove (admin), leave home
- Rooms: list + create
- Inventory nodes: nested browse, create (furniture / storage / item-as-container), search
- Role-aware UI (viewer read-only; editors can mutate)

## Layout

```text
lib/
  app/                 router
  core/                config, theme, utils
  features/
    auth/
    homes/
    rooms/
    inventory/
    search/
  shared/              models, providers, widgets
```

## Tests

```bash
flutter test
flutter analyze
```

## GitHub Actions APK

Workflow: [`.github/workflows/build-apk.yml`](../.github/workflows/build-apk.yml)

1. In the GitHub repo → **Settings → Secrets and variables → Actions**, add:

| Secret | Purpose |
| --- | --- |
| `SUPABASE_URL` | `https://eynsgdzsunlhzrxznriz.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anon/public key |
| `GOOGLE_WEB_CLIENT_ID` | Google **Web** OAuth client ID |
| `ANDROID_KEYSTORE_BASE64` | (optional) base64 of your upload `.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | (optional) keystore password |
| `ANDROID_KEY_ALIAS` | (optional) key alias |
| `ANDROID_KEY_PASSWORD` | (optional) key password |

2. Run **Actions → Build Android APK → Run workflow**, or push to `main`.
3. Download the **homeventory-apk** artifact (`app-release.apk`).

Without a custom upload keystore secret, CI signs with the committed
`mobile/android/ci-upload.jks` so the Google **SHA-1 stays stable**:

```text
B9:53:89:A0:D9:1F:A0:D0:C6:DC:DA:A0:8D:B5:79:8F:F6:A0:E1:FD
```

Register that fingerprint on your Google Cloud **Android** OAuth client
(`com.homeventory.homeventory`).

Encode a production keystore for GitHub (optional later):

```bash
base64 -i upload-keystore.jks | pbcopy   # macOS
base64 -w0 upload-keystore.jks           # Linux
```

## Layout

Being signed in is not enough. Every Home-scoped query relies on Supabase RLS:

```text
active membership in the Home that owns the record
```
