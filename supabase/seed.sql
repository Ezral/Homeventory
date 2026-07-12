# Optional local seed for preview / `supabase db reset` only.
# Hosted production deploys ignore seed by default (GitHub "Deploy to production").
# Auth users still come from Google SSO — do not invent production fixtures here.
select 1;
