#!/usr/bin/env bash
# Link this repo to a hosted Supabase project and push migrations.
#
# Prerequisites:
#   1. Create a free project at https://supabase.com/dashboard
#   2. Create a personal access token: https://supabase.com/dashboard/account/tokens
#   3. Export SUPABASE_ACCESS_TOKEN
#   4. Copy the project ref from Project Settings → General
#
# Usage:
#   export SUPABASE_ACCESS_TOKEN=sbp_...
#   ./scripts/link-and-push.sh <project-ref>
#
# Optional Google OAuth (Auth → Providers → Google):
#   Set the Web client ID/secret in the Supabase dashboard.
#   For local Auth mirroring, also export GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

PROJECT_REF="${1:-}"
if [[ -z "${PROJECT_REF}" ]]; then
  echo "Usage: $0 <project-ref>" >&2
  echo "Project ref looks like: abcdefghijklmnop" >&2
  exit 1
fi

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "SUPABASE_ACCESS_TOKEN is required." >&2
  echo "Create one at https://supabase.com/dashboard/account/tokens" >&2
  exit 1
fi

if [[ ! -x "${ROOT}/node_modules/.bin/supabase" ]]; then
  echo "==> Installing Supabase CLI (npm)"
  npm install --no-fund --no-audit
fi

SUPABASE=("${ROOT}/node_modules/.bin/supabase")

echo "==> Linking project ${PROJECT_REF}"
"${SUPABASE[@]}" link --project-ref "${PROJECT_REF}"

echo "==> Pushing migrations"
"${SUPABASE[@]}" db push

echo "==> Done"
echo
echo "Next:"
echo "  1. Dashboard → Project Settings → API → copy Project URL + anon key"
echo "  2. Dashboard → Authentication → Providers → enable Google"
echo "  3. Run the Flutter app with:"
echo "     flutter run \\"
echo "       --dart-define=SUPABASE_URL=https://${PROJECT_REF}.supabase.co \\"
echo "       --dart-define=SUPABASE_ANON_KEY=<anon-key> \\"
echo "       --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com"
