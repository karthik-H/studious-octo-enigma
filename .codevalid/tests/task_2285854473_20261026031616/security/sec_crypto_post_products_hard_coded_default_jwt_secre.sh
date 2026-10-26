#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_2285854473_20261026031616/api/_infra.sh

CAT="crypto"; SEV="serious"
TITLE="Hard-coded default JWT secret usable in production"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

cv_step Given "register a real user to obtain an existing user id" $LINENO
command -v openssl >/dev/null 2>&1 || { echo "setup failed: openssl missing in seed-test"; exit 1; }
SFX=$(cv_suffix)
EMAIL="seccrypto.$SFX@example.com"
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" '{email:$e,name:"sec crypto",password:"Passw0rd!secret"}')"
[ "$CV_HTTP_STATUS" = "201" ] || { echo "setup failed: register returned $CV_HTTP_STATUS"; exit 1; }
UID_=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ -n "$UID_" ] || { echo "setup failed: no user id"; exit 1; }

cv_step When "forge HS256 token with key dev-only-change-me and POST /products" $LINENO
HDR=$(printf '%s' '{"alg":"HS256","typ":"JWT"}' | b64url)
EXP=$(( $(date +%s) + 3600 ))
PAY=$(jq -nc --arg s "$UID_" --arg e "$EMAIL" --argjson x "$EXP" '{sub:$s,email:$e,exp:$x}' | tr -d '\n' | b64url)
SIG=$(printf '%s' "$HDR.$PAY" | openssl dgst -sha256 -hmac "dev-only-change-me" -binary | b64url)
FORGED="$HDR.$PAY.$SIG"
SKU="CVFORGE-$SFX"
cv_http POST /products "$(product_json "Forged $SFX" "forged token" 1 "$SKU" 1)" -H "Authorization: Bearer $FORGED"
S=$CV_HTTP_STATUS; B=$(printf '%s' "$CV_HTTP_BODY" | tr -d '|\n' | head -c 120)

cv_step Then "verdict from the app response" $LINENO
if [ "$S" = "201" ]; then
  printf 'CV_SECURITY|vulnerable|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" \
    "token signed with dev-only-change-me accepted: POST /products -> 201 product created"
else
  printf 'CV_SECURITY|secure|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" \
    "token signed with dev-only-change-me rejected: POST /products -> $S $B (AUTH_SECRET set in this deployment; code still falls back when unset)"
fi
exit 0
