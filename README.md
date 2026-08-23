# Homeventory

A searchable digital map of everything in your home — where it is, how much remains, and where it moves.

```text
Find it. Track it. Use it. Refill it. Pack it. Put it back.
```

## Product

Homeventory is a collaborative household inventory app for **Android and web** (Flutter) with a Supabase backend.

It models physical containment:

```text
Home → Room → Furniture / Storage → Container → Nested container → Item
```

Items may also be containers (suitcases, bags, boxes). Stock changes are auditable. Consumption predictions are explainable. Packing remembers original locations.

Full product and technical specification: [`docs/Homeventory_Full_Planning.md`](docs/Homeventory_Full_Planning.md)

Implementation backlog: [`docs/IMPLEMENTATION.md`](docs/IMPLEMENTATION.md)

Architecture Decision Records (why the system is built this way): [`docs/adr/`](docs/adr/)

Phase 6–8 prep (**6-super** = stock + Trips MVP → predictions after UAT): [`docs/PHASE_6_8_IMPLEMENTATION_PLAN.md`](docs/PHASE_6_8_IMPLEMENTATION_PLAN.md)

## Stack

| Layer | Choice |
| --- | --- |
| Client | Flutter (Android + web) |
| Auth | Google SSO only via Supabase Auth |
| Backend | Supabase (Postgres, RLS, Storage, Edge Functions) |
| Push | Firebase Cloud Messaging (later) |
| State | Riverpod |
| Web host | GitHub Pages (`https://ezral.github.io/Homeventory/`) |

## Repository layout

```text
docs/                 Product planning, implementation backlog, ADRs
docs/adr/             Architecture Decision Records (accepted decisions only)
supabase/
  migrations/         Schema, RLS helpers, trusted functions
  tests/              Cross-Home authorization SQL tests
scripts/              Migration validation + hosted project link/push
mobile/               Flutter app (Android + web clients)
```

## Current status

- **Backend:** profiles, Homes, membership, invitations (token + short code), rooms, recursive inventory, RLS helpers, invite/move/remove/leave RPCs
- **Flutter client:** Google sign-in, homes, invites, members, rooms, nested inventory browse/create/edit, search, trips packing
- **Web:** GitHub Pages deploy from Actions (same feature set as Android; Google SSO only)
- **Tooling:** `npm` Supabase CLI, `scripts/validate-migrations.sh`, `scripts/link-and-push.sh`

Still needed for a live device/web build: your hosted Supabase project credentials + Google OAuth client IDs (and later FCM).

## Web (GitHub Pages)

After merge to `main`, Actions builds Flutter web and deploys to:

```text
https://ezral.github.io/Homeventory/
```

One-time setup:

1. Repo **Settings → Pages → Source**: **GitHub Actions**.
2. Supabase → Authentication → URL configuration — add redirect:
   - `https://ezral.github.io/Homeventory/**`
3. Google Cloud → OAuth Web client — Authorized JavaScript origins:
   - `https://ezral.github.io`
4. Ensure Actions secrets `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID` are set (same as APK builds).

Workflow: [`.github/workflows/deploy-web.yml`](.github/workflows/deploy-web.yml) · ADR: [`docs/adr/0011-flutter-web-github-pages.md`](docs/adr/0011-flutter-web-github-pages.md)

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
