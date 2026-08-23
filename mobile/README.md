# Homeventory Flutter client

Flutter app for collaborative household inventory — **Android** and **web** (GitHub Pages).

```text
Home → Room → Furniture / Storage → Container → Nested container → Item
```

## Prerequisites

- Flutter stable (3.22+)
- A Supabase project with migrations from `../supabase/migrations` applied
- Google OAuth client configured in Supabase Auth (**Google SSO only**)
- For native Android Google Sign-In: Web client ID as `GOOGLE_WEB_CLIENT_ID`

## Run (Android / Chrome)

From `mobile/`:

```bash
flutter pub get

flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Never put the Supabase **service-role** key in the app.

## Web release (GitHub Pages)

CI builds with `--base-href /Homeventory/` and deploys to
`https://ezral.github.io/Homeventory/`. See root README and
[`docs/adr/0011-flutter-web-github-pages.md`](../docs/adr/0011-flutter-web-github-pages.md).

Local:

```bash
flutter build web --release --base-href /Homeventory/ \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=GOOGLE_WEB_CLIENT_ID=...
cp build/web/index.html build/web/404.html
```

## What’s implemented

- Google SSO only (browser OAuth; native ID token fallback on Android)
- Profile load (created by `handle_new_user` trigger)
- Secure local active-home preference; cleared on logout
- Homes: list, create, archive-ready model, invite create/accept (token or short code)
- Members: list, remove (admin), leave home
- Rooms: list + create
- Inventory nodes: nested browse, create/edit (furniture / storage / item-as-container), search
- Trips packing plan (room or furniture source, items only)
- Role-aware UI (viewer read-only; editors can mutate)
- Edit affordance on every listed child under a room/furniture

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
    trips/
  shared/              models, providers, widgets
```

## Tests

```bash
flutter test
flutter analyze
```

## GitHub Actions

| Workflow | Purpose |
| --- | --- |
| [`.github/workflows/build-apk.yml`](../.github/workflows/build-apk.yml) | Release APK artifact |
| [`.github/workflows/deploy-web.yml`](../.github/workflows/deploy-web.yml) | Flutter web → GitHub Pages |

Required Actions secrets:

| Secret | Purpose |
| --- | --- |
| `SUPABASE_URL` | `https://eynsgdzsunlhzrxznriz.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anon/public key |
| `GOOGLE_WEB_CLIENT_ID` | Google **Web** OAuth client ID |
| `ANDROID_KEYSTORE_*` | (optional) custom APK signing |

Without a custom upload keystore secret, CI signs APKs with the committed
`mobile/android/ci-upload.jks` so the Google **SHA-1 stays stable**:

```text
B9:53:89:A0:D9:1F:A0:D0:C6:DC:DA:A0:8D:B5:79:8F:F6:A0:E1:FD
```

Register that fingerprint on your Google Cloud **Android** OAuth client
(`com.homeventory.homeventory`).

## Security

Being signed in is not enough. Every Home-scoped query relies on Supabase RLS:

```text
active membership in the Home that owns the record
```
