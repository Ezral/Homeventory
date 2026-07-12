# ADR-0002

Google sign-in via Supabase Auth OAuth

## Status

Accepted

## Date

2026-07-12

---

## Context

Users must sign in with Google. Native `google_sign_in` on Android proved fragile under CI APK signing SHA churn (`[16] Account reauth failed` with Credential Manager). The app still needs a reliable SSO path on device builds.

---

## Decision

Primary sign-in path on Android is **Supabase browser OAuth** for Google:

- `AuthRepository.signInWithGoogleOAuth()` calls `client.auth.signInWithOAuth(OAuthProvider.google, …)`.
- Deep link return URL: `com.homeventory.homeventory://login-callback/` (trailing slash required in Supabase Redirect URLs).
- Auth flow: **PKCE** (`AuthFlowType.pkce` in `main.dart`).
- Sign-in UI prefers OAuth; native ID-token exchange remains as a secondary path (`signInWithGoogle()`).

Supporting choices that exist in the repo:

- Profile rows are auto-created by trigger `handle_new_user` on `auth.users` insert.
- Android Manifest disables Credential Manager / credentials API meta-data that interfered with SSO.
- CI uses a **stable upload keystore** (`mobile/android/ci-upload.jks`) so Google / Play SHA-1 does not change per build.
- Only the **Google Web client ID** is passed to the app (`GOOGLE_WEB_CLIENT_ID`); the Web client must authorize the Supabase callback `https://<project>.supabase.co/auth/v1/callback`.

On logout, local private state (`active_home_id` in secure storage) is cleared, then Supabase / Google sessions are signed out.

---

## Rationale

- **Reliability:** Browser OAuth depends on Supabase + Google Web client configuration, not on Android SHA matching for every debug/CI variant.
- **Security:** PKCE OAuth; no service-role on device; profile identity equals `auth.users.id`.
- **Productivity:** One OAuth provider configuration in Supabase Dashboard serves the app.

---

## Alternatives Considered

1. **Native Google Sign-In ID token → `signInWithIdToken` only**  
   Attempted; failed intermittently on Android with Credential Manager / SHA mismatch. Kept as fallback, not primary.

2. **Email/password Auth**  
   Not implemented; product decision is Google SSO.

3. **Magic link / OTP**  
   Not implemented.

---

## Consequences

### Advantages

- Working SSO on release APKs once Redirect URLs and Web client secret match.
- Profile creation does not require a separate client insert (RLS forbids client profile insert).

### Disadvantages

- Leaves the app for a browser / Custom Tab; UX is slightly heavier than native sheet.
- Misconfigured Redirect URL trailing slash or wrong Web client breaks login with opaque errors.
- Native path still exists and can confuse maintainers if both are used without preference.

---

## Security Impact

- Session tokens stored by `supabase_flutter` / secure storage stack.
- Profiles: users can select/update own row; fellow-member profile select is allowed within shared Homes (migration `20260712000200`).
- Clients cannot insert profiles directly (`profiles_no_client_insert`).

---

## Database Impact

- Table: `profiles` (PK = `auth.users.id`).
- Trigger: `on_auth_user_created` → `handle_new_user`.
- Related fix: profile backfill in `20260712000300_homes_rls_grants.sql`.

---

## API Impact

- Supabase Auth OAuth + session refresh.
- Deep link intent filter on `MainActivity` for `com.homeventory.homeventory` / `login-callback`.

---

## UI Impact

- `SignInScreen` drives Google SSO.
- `GoRouter` redirects unauthenticated users to `/sign-in`.
- Unconfigured builds show `SetupRequiredScreen` instead of auth.

---

## Future Considerations

- If native Google Sign-In becomes stable again, an ADR update should record which path is canonical.
- Additional OAuth providers would reuse the same PKCE + deep-link pattern.

---

## Architecture Notes

- Two Google Web clients historically caused provider mismatch; ops must keep Supabase Google provider and `GOOGLE_WEB_CLIENT_ID` aligned.
- Architecture drift risk: dual sign-in methods without a single documented “preferred” call site beyond UI preference.

---

## References

- [`mobile/lib/features/auth/data/auth_repository.dart`](../../mobile/lib/features/auth/data/auth_repository.dart)
- [`mobile/lib/features/auth/presentation/sign_in_screen.dart`](../../mobile/lib/features/auth/presentation/sign_in_screen.dart)
- [`mobile/android/app/src/main/AndroidManifest.xml`](../../mobile/android/app/src/main/AndroidManifest.xml)
- [`supabase/migrations/20260712000100_foundation.sql`](../../supabase/migrations/20260712000100_foundation.sql) (profiles)
- PRs: [#8](https://github.com/Ezral/Homeventory/pull/8), [#9](https://github.com/Ezral/Homeventory/pull/9)
- Related: [ADR-0001](0001-flutter-supabase-platform.md), [ADR-0003](0003-home-membership-rls.md)
