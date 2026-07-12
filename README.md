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
| Push | Firebase Cloud Messaging |
| State | Riverpod (planned) |

## Repository layout

```text
docs/                 Product planning and implementation backlog
supabase/
  migrations/         Schema, RLS helpers, trusted functions
  tests/              Cross-Home authorization SQL tests
mobile/               Flutter app (to be scaffolded in Phase 1)
```

## Current status

Foundation scaffolding for **Phase 1–3** (auth/profile model, Homes, membership, rooms, recursive inventory nodes, RLS helpers).

Not yet wired: live Supabase project, Flutter client, Google OAuth credentials, or FCM.

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

Flutter is not scaffolded yet. When Phase 1 client work begins:

```bash
flutter create --org com.homeventory --project-name homeventory mobile
```

Then configure Supabase URL + anon key via secure environment injection — never embed the service-role key in the APK.

## Security rule

Every request must prove:

```text
The authenticated user is an active member of the Home that owns the requested record.
```

Being logged in is not enough. RLS is deny-by-default on every exposed table.

## License

Private / TBD.
