# Supabase backend

Schema and RLS for Homeventory. Source of truth for product rules: [`../docs/Homeventory_Full_Planning.md`](../docs/Homeventory_Full_Planning.md).

## Migrations

| Migration | Scope |
| --- | --- |
| `20260712000100_foundation.sql` | Profiles, Homes, members, invitations, rooms, inventory nodes, RLS helpers, `move_inventory_node`, invite create/accept RPCs |

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
- `accept_invitation(token)` — activates membership; single-use
- `move_inventory_node(node, room, parent?)` — cycle-safe move with subtree room propagation

## Local

```bash
supabase start
supabase db reset
supabase test db
```

Configure Google OAuth client ID/secret via `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` for local Auth.
