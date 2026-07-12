# Supabase backend

Schema and RLS for Homeventory. Source of truth for product rules: [`../docs/Homeventory_Full_Planning.md`](../docs/Homeventory_Full_Planning.md).

## Migrations

| Migration | Scope |
| --- | --- |
| `20260712000100_foundation.sql` | Profiles, Homes, members, invitations, rooms, inventory nodes, RLS helpers, `move_inventory_node`, invite create/accept RPCs |
| `20260712000200_invite_members_integration.sql` | Short-code invite accept, `remove_home_member`, `leave_home`, fellow-member profile visibility |

Later phases add products, transactions, images, barcodes, trips, predictions, notifications, and audit logs.

## Core authorization helpers

```text
is_home_member(home_id)
home_role_of(home_id)
can_view_home(home_id)          -- any ACTIVE member
can_edit_inventory(home_id)     -- OWNER | ADMIN | EDITOR
can_manage_members(home_id)     -- OWNER | ADMIN
can_admin_home(home_id)         -- OWNER
```

Every Home-scoped table stores `home_id` and enables RLS.

## Trusted RPCs

- `create_invitation(...)` — stores SHA-256 of token only
- `accept_invitation(token_or_short_code)` — activates membership; single-use
- `remove_home_member(home_id, user_id)` — soft-remove (OWNER/ADMIN)
- `leave_home(home_id)` — voluntary leave (non-OWNER)
- `move_inventory_node(node, room, parent?)` — cycle-safe move with subtree room propagation

## Connect a hosted Supabase project

1. Create a project at [supabase.com/dashboard](https://supabase.com/dashboard).
2. Create an access token at [Account → Access Tokens](https://supabase.com/dashboard/account/tokens).
3. From the repo root:

```bash
npm install
export SUPABASE_ACCESS_TOKEN=sbp_...
./scripts/link-and-push.sh YOUR_PROJECT_REF
```

4. Enable **Google** under Authentication → Providers (Web client ID + secret).
5. Copy **Project URL** and **anon** key into the Flutter `--dart-define` flags (see root README).

Never ship the **service-role** key in the mobile app.

## Validate migrations without Docker

If the full local stack cannot run, Postgres-only validation still works:

```bash
./scripts/validate-migrations.sh
```

## Local stack (Docker required)

```bash
cp supabase/.env.example supabase/.env   # fill Google OAuth for local Auth
npm install
npx supabase start
npx supabase db reset
npx supabase test db
```

Configure Google OAuth client ID/secret via `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` for local Auth.
