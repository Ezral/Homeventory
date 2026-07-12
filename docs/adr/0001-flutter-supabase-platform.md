# ADR-0001

Flutter client + Supabase backend platform

## Status

Accepted

## Date

2026-07-12

---

## Context

Homeventory needs a mobile client that can use camera, barcode scanning, and secure auth, plus a multi-tenant backend with strong row-level authorization. The product is Android-first and collaborative across households.

A platform decision was required so schema, auth, storage, and the app share one deployment model.

---

## Decision

Homeventory uses:

| Layer | Choice in repo today |
| --- | --- |
| Mobile client | Flutter under `mobile/` (Android primary) |
| Backend | Hosted Supabase (Postgres + Auth + Storage) |
| Schema delivery | SQL migrations in `supabase/migrations/`, deployed by merging to `main` (GitHub ↔ Supabase integration) |
| Client config | Compile-time `--dart-define` for `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID` |
| APK builds | GitHub Actions workflow `.github/workflows/build-apk.yml` with a stable CI keystore |

The client ships only the **anon / publishable** key. The service-role key is never embedded in the APK.

Edge Functions, Firebase Cloud Messaging, and Realtime subscriptions are **not** implemented yet even though they appear in product planning.

---

## Rationale

- **Security:** Authorization can be enforced in Postgres RLS, not only in Flutter UI.
- **Productivity:** Auth, Postgres, and Storage in one platform reduces custom backend work for an early product.
- **Maintainability:** Migrations as versioned SQL match how the team already ships schema.
- **Android-first:** Flutter covers camera and scanner plugins used later; iOS is deferred.

---

## Alternatives Considered

1. **Custom backend (Node/Go + Postgres)**  
   Rejected for MVP: more ops surface (auth, storage, deploy) without clear benefit yet.

2. **Firebase-only (Firestore + Auth)**  
   Rejected: relational containment, recursive moves, and SQL trusted functions fit Postgres better.

3. **Native Android (Kotlin) only**  
   Rejected: planning targets Flutter for future iOS reuse; current team delivered Flutter.

4. **Embed service-role in the app**  
   Rejected: would bypass RLS and expose all Homes.

---

## Consequences

### Advantages

- Single backend project for Auth, data, and private images.
- Schema changes are reviewable PRs.
- Client can fail closed when dart-defines are missing (`SetupRequiredScreen`).

### Disadvantages

- Hosted Supabase grant/RLS quirks must be handled explicitly (see migration `20260712000300_homes_rls_grants.sql`).
- Compile-time secrets require CI wiring; local runs need dart-defines.
- Flutter web targets exist in the tree but are not the product surface.

---

## Security Impact

- Clients authenticate with Supabase Auth JWTs.
- Data access depends on RLS policies; UUID knowledge alone is not authorization.
- Forking the GitHub repo does not grant database access; Actions secrets are not copied to forks.

---

## Database Impact

Migrations today:

- `20260712000100_foundation.sql`
- `20260712000200_invite_members_integration.sql`
- `20260712000300_homes_rls_grants.sql`
- `20260712000400_images_barcodes.sql`

Validation: `scripts/validate-migrations.sh`, `supabase/tests/rls_cross_home.test.sql`.

---

## API Impact

- **PostgREST** via `supabase_flutter` table queries.
- **RPC** for trusted operations (`accept_invitation`, `create_invitation`, `move_inventory_node`, membership helpers, etc.).
- **Storage** API for private bucket `home-images`.
- **Auth** API for OAuth / session.
- No custom Edge Functions in the repo.

---

## UI Impact

- App boots only after `AppConfig.isConfigured`.
- Feature screens talk to Supabase through repositories, not raw service-role calls.

---

## Future Considerations

- Edge Functions may appear for push or scheduled jobs; they should get their own ADR when added.
- A separate staging Supabase project may be needed if production and preview DBs diverge.

---

## Architecture Notes

- README stack table mentions Edge Functions and FCM; those are planning intent, not current runtime.
- `cover_image_id` / `image_id` columns exist on homes/rooms but are not wired end-to-end in the Flutter UI.
- Trigram / full-text search extensions are not enabled; name search uses `ilike`.

---

## References

- [`supabase/migrations/`](../../supabase/migrations/)
- [`mobile/lib/core/config/app_config.dart`](../../mobile/lib/core/config/app_config.dart)
- [`mobile/lib/main.dart`](../../mobile/lib/main.dart)
- [`.github/workflows/build-apk.yml`](../../.github/workflows/build-apk.yml)
- PRs: [#1](https://github.com/Ezral/Homeventory/pull/1), [#2](https://github.com/Ezral/Homeventory/pull/2), [#3](https://github.com/Ezral/Homeventory/pull/3), [#4](https://github.com/Ezral/Homeventory/pull/4)
