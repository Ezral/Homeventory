# Architecture Decision Records

This directory is the source of truth for **why** Homeventory is built the way it is.
The source code remains the source of truth for **how**.

## Rules

1. Document only architecture that exists in the repository today.
2. Do not invent future architecture in ADRs.
3. Before writing: search existing ADRs; update if the decision already exists.
4. A PR that changes architecture is not complete until the relevant ADR is created or updated.
5. Use sequential numbering: `NNNN-short-kebab-title.md`.

## Index

| ADR | Title | Status |
| --- | --- | --- |
| [0001](0001-flutter-supabase-platform.md) | Flutter client + Supabase backend platform | Accepted |
| [0002](0002-google-auth-supabase-oauth.md) | Google sign-in via Supabase Auth OAuth | Accepted |
| [0003](0003-home-membership-rls.md) | Home membership and Postgres RLS | Accepted |
| [0004](0004-hashed-home-invitations.md) | Hashed invitations (token + short code) | Accepted |
| [0005](0005-recursive-inventory-nodes.md) | Unified recursive inventory nodes | Accepted |
| [0006](0006-private-images-and-barcodes.md) | Private images Storage + item barcodes | Accepted |
| [0007](0007-flutter-client-architecture.md) | Flutter client structure (Riverpod, go_router, repositories) | Accepted |

## Not yet documented (not implemented)

These planned areas from `Homeventory_Full_Planning.md` do **not** have ADRs yet because they are not in the codebase:

- Product / container stock model
- Inventory transactions
- Consumption predictions
- Packing / trips
- Notifications / FCM
- Audit log subsystem
