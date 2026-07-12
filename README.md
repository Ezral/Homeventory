# Homeventory

A searchable digital map of everything in your home — where it is, how much remains, and where it moves.

```text
Find it. Track it. Use it. Refill it. Pack it. Put it back.
```

## Product

Homeventory is a collaborative household inventory app for Android (Flutter) with a Supabase backend.

It models physical containment:

```text
Home → Room → Furniture / Storage → Container → Nested container → Item
```

Items may also be containers (suitcases, bags, boxes). Stock changes are auditable. Consumption predictions are explainable. Packing remembers original locations.

Full product and technical specification: [`docs/Homeventory_Full_Planning.md`](docs/Homeventory_Full_Planning.md)

Implementation backlog: [`docs/IMPLEMENTATION.md`](docs/IMPLEMENTATION.md)

## Stack

| Layer | Choice |
| --- | --- |
| Client | Flutter (Android-first) |
| Auth | Google SSO via Supabase Auth |
| Backend | Supabase (Postgres, RLS, Storage, Edge Functions) |
| Push | Firebase Cloud Messaging (later) |
| State | Riverpod |

## Repository layout

```text
docs/                 Product planning and implementation backlog
supabase/
  migrations/         Schema, RLS helpers, trusted functions
  tests/              Cross-Home authorization SQL tests
scripts/              Migration validation + hosted project link/push
mobile/               Flutter app (Phase 1–3 client)
```

## Current status

- **Backend:** profiles, Homes, membership, invitations (token + short code), rooms, recursive inventory, RLS helpers, invite/move/remove/leave RPCs
- **Flutter client:** Google sign-in, homes, invites, members, rooms, nested inventory browse/create, search
- **Tooling:** `npm` Supabase CLI, `scripts/validate-migrations.sh`, `scripts/link-and-push.sh`

Still needed for a live device build: your hosted Supabase project credentials + Google OAuth client IDs (and later FCM).

## Connect Supabase (hosted)

### Option A — GitHub integration (recommended)

In the Supabase dashboard: **Project Settings → Integrations → GitHub**.

1. Connect the `Ezral/Homeventory` repository.
2. Set **Working directory** to `.` (`supabase/` is at the repo root).
3. Enable **Automatic branching** (preview DB per PR) and **Deploy to production** (apply migrations on merge to `main`).
4. Merge [PR #3](https://github.com/Ezral/Homeventory/pull/3) (or any PR that contains `supabase/migrations`) into `main` to deploy the Phase 1–3 schema.
5. Dashboard → Authentication → Providers → enable **Google** (Web client ID + secret).
6. Copy Project URL + **anon** key into the Flutter run command below.

### Option B — CLI push

```bash
npm install
export SUPABASE_ACCESS_TOKEN=sbp_...
./scripts/link-and-push.sh YOUR_PROJECT_REF
```

Details: [`supabase/README.md`](supabase/README.md)

## Validate migrations (no Docker)

```bash
./scripts/validate-migrations.sh
```

## Local setup (full stack — Docker required)

```bash
cp supabase/.env.example supabase/.env   # optional Google OAuth for local Auth
npm install
npx supabase start
npx supabase db reset
npx supabase test db
```

## Local setup (mobile)

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Use only the Supabase **anon** key in the client — never the service-role key.
See `mobile/.env.example` for the variable list.

## Security rule

Every request must prove:

```text
The authenticated user is an active member of the Home that owns the requested record.
```

Being logged in is not enough. RLS is deny-by-default on every exposed table.

## License

Private / TBD.
