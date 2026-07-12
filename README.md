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
mobile/               Flutter app (Phase 1–3 client)
```

## Current status

- **Backend foundation:** profiles, Homes, membership, invitations, rooms, recursive inventory nodes, RLS helpers, invite/move RPCs
- **Flutter client:** Google sign-in, homes, invites, rooms, nested inventory browse/create, search

Still needed for a live build: Supabase project credentials, Google OAuth client IDs, and (later) FCM.

## Local setup (backend)

1. Install the [Supabase CLI](https://supabase.com/docs/guides/cli).
2. From the repo root:

```bash
supabase start
supabase db reset
```

3. Run authorization tests when ready:

```bash
supabase test db
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

## Security rule

Every request must prove:

```text
The authenticated user is an active member of the Home that owns the requested record.
```

Being logged in is not enough. RLS is deny-by-default on every exposed table.

## License

Private / TBD.
