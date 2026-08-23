# ADR-0011

Flutter web client on GitHub Pages

## Status

Accepted

## Date

2026-08-23

---

## Context

The product needed the same Homeventory feature set in a browser, hosted without a separate web hosting vendor, with Google SSO only.

---

## Decision

Ship the existing Flutter client to **web** and host it on **GitHub Pages**:

| Concern | Choice |
| --- | --- |
| App | Same `mobile/` Flutter codebase (Android + web) |
| Host | GitHub Pages via Actions pushing the `gh-pages` branch (`deploy-web.yml`) |
| URL | `https://ezral.github.io/Homeventory/` (`--base-href /Homeventory/`) |
| Auth | Google SSO only via Supabase OAuth (PKCE); web redirect is the Pages origin |
| SPA routing | Copy `index.html` → `404.html` so path URLs work on Pages |
| Responsive web | Viewport ≥ 900px → sidebar + panes; narrower browser → phone UI (bottom nav) |

Barcode camera on web falls back to manual entry when the browser camera path is unavailable. Item rows under furniture/room browse expose an **Edit** action so attributes like “also a container” are reachable without hunting through details.

---

## Rationale

- One codebase keeps Android and web feature parity.
- GitHub Pages is free for a public repo and deploys from the same Actions secrets already used for APK builds.
- Google-only SSO matches the product auth decision (ADR-0002).

---

## Alternatives Considered

1. **Separate React/Next web app** — rejected; duplicates inventory/trips logic.
2. **Firebase Hosting / Vercel** — rejected for MVP; Pages is already in the GitHub workflow.

---

## Consequences

### Advantages

- Browser access with the same Supabase RLS and RPCs.
- Deploy on merge to `main` when `mobile/**` changes.

### Disadvantages

- Operator must add the Pages URL to Supabase Auth redirect allow-list and Google authorized origins.
- Camera/barcode UX is weaker on desktop browsers than on Android.

---

## Security Impact

- Still ships only the anon key via `--dart-define`.
- OAuth redirect must be an allow-listed HTTPS Pages URL (no open redirects).

---

## Database Impact

None.

---

## API Impact

None (same Supabase project).

---

## UI Impact

- Web build of the Flutter UI with **responsive** chrome: desktop sidebar + inventory split panes; mobile browser keeps the app GUI
- Furniture/room child rows: overflow menu with Edit / Details / Open

---

## Architecture Notes

After first deploy of the `gh-pages` branch, set GitHub repo **Settings → Pages**:

- **Source:** Deploy from a branch
- **Branch:** `gh-pages` / `/ (root)`

Supabase Dashboard → Authentication → URL configuration — add:

- Site URL (optional for web): `https://ezral.github.io/Homeventory/`
- Redirect URLs: `https://ezral.github.io/Homeventory/**`

Google Cloud OAuth Web client — Authorized JavaScript origins: `https://ezral.github.io`

---

## References

- [`.github/workflows/deploy-web.yml`](../../.github/workflows/deploy-web.yml)
- [ADR-0001](0001-flutter-supabase-platform.md), [ADR-0002](0002-google-auth-supabase-oauth.md)
- [`mobile/lib/features/auth/`](../../mobile/lib/features/auth/)
