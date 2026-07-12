# ADR-0003

Home membership and Postgres RLS

## Status

Accepted

## Date

2026-07-12

---

## Context

Inventory data is sensitive and multi-tenant. Knowing a UUID must never grant access to another household’s rows. Authorization cannot live only in Flutter screens.

---

## Decision

**Primary authorization rule:** a user may access a Home-scoped record only if they have an **ACTIVE** `home_members` row for that `home_id` (and role permits the write).

Shared security-definer helpers (stable, `search_path = public`):

| Function | Meaning |
| --- | --- |
| `is_home_member(home_id)` | ACTIVE membership |
| `home_role_of(home_id)` | Role or null |
| `can_view_home(home_id)` | Same as member |
| `can_edit_inventory(home_id)` | OWNER, ADMIN, EDITOR |
| `can_manage_members(home_id)` | OWNER, ADMIN |
| `can_admin_home(home_id)` | OWNER |

RLS is enabled on Home-scoped tables. Policies call these helpers explicitly (deny-by-default).

Home lifecycle today:

- Any authenticated user may **insert** a `homes` row with `created_by_user_id = auth.uid()`.
- Trigger `handle_new_home` inserts the creator as **OWNER** / **ACTIVE**.
- Extra SELECT policy `homes_select_creator` allows `INSERT … RETURNING` before membership-based select would otherwise fail.
- Updates/deletes on homes are OWNER-only via `can_admin_home`.
- Soft archive uses `archived_at` (client filters archived homes out of lists).

Membership changes that must be atomic use RPCs:

- `remove_home_member`
- `leave_home`

Table grants for `authenticated` are asserted in `20260712000300_homes_rls_grants.sql` because hosted migrations do not always inherit dashboard defaults.

---

## Rationale

- **Security:** Database enforces tenancy even if the client is buggy or malicious.
- **Simplicity:** One `home_id` column on child tables; helpers stay reusable.
- **Maintainability:** Role checks centralized; policies stay short.

---

## Alternatives Considered

1. **Authorize only in the Flutter app**  
   Rejected: trivial to bypass with PostgREST + anon key + stolen JWT scope mistakes.

2. **Per-row ACLs without Home membership**  
   Rejected: too complex for household collaboration.

3. **Supabase “organizations” third-party pattern**  
   Rejected: custom `homes` / `home_members` matches the product language.

4. **Hard-delete members only**  
   Soft status (`REMOVED` / `LEFT`) preferred so history can be added later; RPCs implement soft-remove today.

---

## Consequences

### Advantages

- Cross-Home UUID guessing fails closed (covered by SQL smoke tests).
- Viewer role can read but not edit inventory (policy + client checks).
- Creator→OWNER path does not require a second client round-trip.

### Disadvantages

- `INSERT … RETURNING` needs the creator SELECT policy; easy to regress.
- Security-definer helpers must keep `search_path` fixed to avoid privilege surprises.
- Client still duplicates some role checks for UX (buttons); server remains authoritative.

---

## Security Impact

- Roles: OWNER, ADMIN, EDITOR, VIEWER.
- Invitations cannot grant OWNER (`invitations_role_not_owner` + RPC checks).
- Fellow members can read limited profile fields of each other (policy in migration 002).
- Removing a member should immediately fail `can_view_home` for that user.

---

## Database Impact

**Tables:** `homes`, `home_members`, plus all tables that RLS via `home_id`.

**Indexes:** `home_members_user_id_idx`, partial active membership index.

**Triggers:** `on_home_created` → OWNER membership.

**Migrations:** foundation + invite/members + homes RLS grants.

---

## API Impact

- Direct PostgREST on `homes` / `home_members` where policies allow.
- RPC: `home_role_of`, `remove_home_member`, `leave_home`, invitation RPCs (see ADR-0004).

---

## UI Impact

- Homes list from memberships join.
- Home detail gates invite / add-room / inventory edit on `myRole`.
- Join Home screen accepts invitation token or short code.

---

## Future Considerations

- Ownership transfer and change-role UI are planned; should extend RPCs rather than loosening RLS.
- Restore-from-archive flows are not built yet.

---

## Architecture Notes

- `can_admin_home` is OWNER-only; ADMIN cannot update home row settings today even if product text sometimes groups “admins.”
- No audit_logs table yet; membership removals are not separately audited.
- Duplicate authorization logic exists in Flutter (`HomeRole.canEditInventory`) — acceptable for UX, but server policies must stay stricter or equal.

---

## References

- [`supabase/migrations/20260712000100_foundation.sql`](../../supabase/migrations/20260712000100_foundation.sql)
- [`supabase/migrations/20260712000200_invite_members_integration.sql`](../../supabase/migrations/20260712000200_invite_members_integration.sql)
- [`supabase/migrations/20260712000300_homes_rls_grants.sql`](../../supabase/migrations/20260712000300_homes_rls_grants.sql)
- [`supabase/tests/rls_cross_home.test.sql`](../../supabase/tests/rls_cross_home.test.sql)
- [`mobile/lib/features/homes/data/homes_repository.dart`](../../mobile/lib/features/homes/data/homes_repository.dart)
- PRs: [#1](https://github.com/Ezral/Homeventory/pull/1), [#11](https://github.com/Ezral/Homeventory/pull/11)
- Related: [ADR-0004](0004-hashed-home-invitations.md)
