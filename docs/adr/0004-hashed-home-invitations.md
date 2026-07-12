# ADR-0004

Hashed home invitations (token + short code)

## Status

Accepted

## Date

2026-07-12

---

## Context

Homes need a way to add members without making the Home world-readable. Invite links must be shareable, single-use (status transition), expiring, and safe if the `invitations` table is leaked.

---

## Decision

Invitations store **SHA-256 hashes** of long tokens, never the plaintext token.

Flow that exists today:

1. Client generates a high-entropy token (`generateInviteToken`, length 40) and a human short code (`generateShortCode`).
2. Client calls RPC `create_invitation` with plaintext token + short code + role + expiry hours.
3. Database stores `token_hash = encode(digest(token, 'sha256'), 'hex')` and optional `short_code`.
4. UI shows the plaintext token / short code **once** to the inviter.
5. Invitee calls `accept_invitation(p_token)`:
   - input length ≥ 32 → treat as raw token, hash and lookup `token_hash`
   - shorter input → lookup `short_code` (case-insensitive)
6. On success: upsert ACTIVE `home_members`, mark invitation ACCEPTED.

Constraints / policies:

- Role cannot be OWNER.
- Only OWNER/ADMIN (`can_manage_members`) can create/list/update invitations.
- Optional `invited_email` restricts accept to matching JWT email.
- Default expiry is configurable via RPC hours (UI currently uses 168 hours).

Invite QR codes are **not** implemented yet (planning only).

---

## Rationale

- **Security:** DB leak of `invitations` does not reveal usable long tokens.
- **Usability:** Short codes work for verbal / SMS sharing; long tokens for links.
- **Correctness:** Accept is a security-definer RPC so invitees do not need SELECT on arbitrary invitations.

---

## Alternatives Considered

1. **Store plaintext tokens in the database**  
   Rejected: unnecessary secret exposure.

2. **Email-only invites via Supabase magic links**  
   Rejected for MVP: product wants in-app code/link sharing across household members who may already have Google accounts.

3. **Open join codes on the Home row**  
   Rejected: weaker lifecycle (expiry, single-use, role) than invitation records.

---

## Consequences

### Advantages

- Managers can mint role-scoped invites without granting OWNER.
- Re-accepting (conflict on `home_id, user_id`) can reactivate a previously removed member.

### Disadvantages

- Short codes are lower entropy than tokens; they are mitigated by expiry + single ACTIVE accept, but brute force is a residual risk if codes are long-lived and guessable.
- Plaintext token exists briefly on the inviter device and in chat when shared.
- No revoke UI beyond status field capability in schema (revoke path not fully exposed in Flutter).

---

## Security Impact

- RLS: invitation rows visible only to member managers.
- Accept path does not open a general SELECT on invitations to all authenticated users.
- Token minimum length enforced in `create_invitation` (≥ 32).

---

## Database Impact

- Table: `invitations`
- Indexes: `home_id`, partial active expiry index, unique `token_hash`, unique `short_code`
- RPCs: `create_invitation`, `accept_invitation` (short-code aware in migration 002)

---

## API Impact

- RPC-only create/accept for the secure path.
- No Edge Function mailer.

---

## UI Impact

- Home detail invite sheet creates invitation and displays token + short code (copy).
- Join Home screen submits token or code to `acceptInvitation`.

---

## Future Considerations

- QR encoding of the token/link.
- Explicit revoke button and invite list UI.
- Rate limiting accept attempts (not present today).

---

## Architecture Notes

- Short-code alphabet omits ambiguous characters (`I`, `O`, `0`, `1`) — good; document if changing.
- Missing index solely on `upper(short_code)` — lookup uses `upper(short_code) = upper(input)`; may not use a simple unique index efficiently at scale (observe if Homes grow large invite volume).
- No audit log of who invited whom beyond columns on `invitations` / `home_members`.

---

## References

- [`supabase/migrations/20260712000100_foundation.sql`](../../supabase/migrations/20260712000100_foundation.sql)
- [`supabase/migrations/20260712000200_invite_members_integration.sql`](../../supabase/migrations/20260712000200_invite_members_integration.sql)
- [`mobile/lib/core/utils/invite_token.dart`](../../mobile/lib/core/utils/invite_token.dart)
- [`mobile/lib/features/homes/data/homes_repository.dart`](../../mobile/lib/features/homes/data/homes_repository.dart)
- Related: [ADR-0003](0003-home-membership-rls.md)
