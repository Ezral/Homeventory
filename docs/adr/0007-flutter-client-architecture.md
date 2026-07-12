# ADR-0007

Flutter client architecture (Riverpod, go_router, repositories)

## Status

Accepted

## Date

2026-07-12

---

## Context

The Android client must talk to Supabase securely, keep feature code navigable, and stay testable without embedding secrets. An application structure decision was needed once Phase 1–3 screens landed.

---

## Decision

The Flutter app under `mobile/` uses:

| Concern | Choice |
| --- | --- |
| State / DI | `flutter_riverpod` (`ProviderScope`, feature providers) |
| Navigation | `go_router` with auth redirect (`routerProvider`) |
| Data access | Feature **repositories** (`AuthRepository`, `HomesRepository`, `RoomsRepository`, `InventoryRepository`) wrapping `SupabaseClient` |
| Config | `AppConfig.fromEnvironment()` via `--dart-define` |
| Local private state | `FlutterSecureStorage` through `LocalSessionStore` (active home id; cleared on logout) |
| Theming | Central `buildHomeventoryTheme()` |
| Feature layout | `lib/features/{auth,homes,rooms,inventory,search}/` + `lib/shared/` |

Navigation pattern for create/edit flows: **`context.push` / `context.pop`** so the previous screen remains on the stack (not `go` that replaces the stack for those flows).

Online-first: no offline sync queue or local SQLite inventory cache in the app today.

---

## Rationale

- **Maintainability:** Feature folders keep screens near their repositories.
- **Security:** Config and session helpers discourage hard-coding keys; logout clears private prefs.
- **Developer productivity:** Riverpod + repositories match common Flutter Supabase apps and keep widgets thin.
- **UX correctness:** Push/pop preserves back navigation after add/edit.

---

## Alternatives Considered

1. **Bloc / Cubit everywhere**  
   Not chosen; Riverpod already wired in scaffold.

2. **Call Supabase directly from widgets**  
   Rejected: duplicates auth/error handling; harder to test.

3. **Auto-route / Navigator 1.0 only**  
   `go_router` selected for declarative auth redirects and deep links (OAuth callback is Manifest-based; app routes are path-based).

4. **Full offline-first Drift database**  
   Deferred (explicitly post-MVP in planning).

---

## Consequences

### Advantages

- Clear place to put new features (mirror `features/<name>`).
- Setup mode works without initializing Supabase when defines are missing.
- Providers invalidate after writes so lists refresh.

### Disadvantages

- Some cross-feature provider placement is uneven (`inventoryRepositoryProvider` lives under `rooms_providers.dart`).
- Limited automated UI tests (smoke + model tests only).

---

## Security Impact

- Anon key only in the client.
- Secure storage used for active home preference.
- Role-gated controls in UI are advisory; RLS is authoritative (ADR-0003).

---

## Database Impact

None directly; client consumes schema from ADR-0003–0006.

---

## API Impact

Repositories use:

- `.from(...).select/insert/update/delete`
- `.rpc(...)` for trusted functions
- `storage.from('home-images')` for media
- `auth.signInWithOAuth` / `signOut`

---

## UI Impact

Current primary screens:

- Sign-in, homes list, create/join home, home detail (members + rooms)
- Create/edit room, room/container inventory browse
- Create/edit node, node detail (photos/barcodes)
- Search + barcode scan

---

## Future Considerations

- Split inventory providers out of `rooms_providers.dart` when transactions/packing arrive.
- Add crash reporting and structured logging (called out in Phase 1 backlog; not present).

---

## Architecture Notes

- Provider organization drift: inventory providers colocated with rooms — workable but confusing for newcomers.
- `CreateHomeScreen` still uses `context.go` after create (replaces stack); room/node flows use `pop`. Inconsistent navigation after create home vs create room.
- No global error reporting layer; failures surface as SnackBars / `ErrorView`.
- `home_members` embed of `profiles` must use an explicit FK hint (`profiles!home_members_user_id_fkey`) because both `user_id` and `invited_by_user_id` reference profiles (PostgREST PGRST201 otherwise).

---

## References

- [`mobile/lib/main.dart`](../../mobile/lib/main.dart)
- [`mobile/lib/app/router.dart`](../../mobile/lib/app/router.dart)
- [`mobile/lib/shared/providers/supabase_provider.dart`](../../mobile/lib/shared/providers/supabase_provider.dart)
- [`mobile/lib/features/`](../../mobile/lib/features/)
- PRs: [#2](https://github.com/Ezral/Homeventory/pull/2), [#12](https://github.com/Ezral/Homeventory/pull/12)
- Related: [ADR-0001](0001-flutter-supabase-platform.md)
