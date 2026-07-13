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
| [0008](0008-inventory-transactions.md) | Inventory transactions and dispose | Accepted |
| [0009](0009-trips-packing.md) | Trips packing and unpacking | Accepted |
| [0010](0010-home-currency-fx-cache.md) | Home-currency FX cache via Frankfurter | Accepted |

## Not yet documented (not implemented)

Prep notes:

- [`../PHASE_6_8_IMPLEMENTATION_PLAN.md`](../PHASE_6_8_IMPLEMENTATION_PLAN.md) — 6-super shipped; Phase 8 predictions
- [`../UAT_PHASE6_SUPER_FOLLOWUP.md`](../UAT_PHASE6_SUPER_FOLLOWUP.md) — post-UAT phases A–J

Still without ADRs (not implemented or not landed as architecture):

- Room-level authorization, visibility, requests, temporary access
- Multi-dispenser product assignments
- User display-currency preference (home-currency FX sum already shipped)
- Full product / multi-reserve catalog model
- Consumption predictions
- Notifications / FCM
- Permission / access audit log subsystem
- Page-ready image loading strategy
