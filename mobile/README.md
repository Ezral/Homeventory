# Homeventory Flutter client

Android-first Flutter app. Scaffold during Phase 1:

```bash
# from repository root
flutter create --org com.homeventory --project-name homeventory mobile
```

## Planned dependencies

- `supabase_flutter` — Auth + Postgres API
- `flutter_riverpod` — state management
- `google_sign_in` — Google SSO
- `flutter_secure_storage` — session tokens
- Camera / image crop / barcode packages in later phases

## Rules

- Use only the Supabase **anon** key in the client.
- Never ship the **service-role** key in the APK.
- Treat UUIDs as identifiers, not authorization — RLS decides access.
- Online-first with minimal local cache for MVP.
