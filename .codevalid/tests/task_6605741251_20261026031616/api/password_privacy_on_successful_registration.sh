#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

# Given
cv_step Given "a unique email and a distinctive password" $LINENO
EMAIL=$(unique_email private)
PASSWORD="Pr1vate!Secret$(cv_suffix)"

# When
cv_step When "POST /auth/register with the email and password" $LINENO
cv_http POST /auth/register "$(register_body "$EMAIL" "Private Person" "$PASSWORD")"

# Then
cv_step Then "201 confirms creation; response has no raw/encoded password; stored value is not the raw password" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.email')" = "$EMAIL" ] || cv_fail "expected .user.email=$EMAIL" $LINENO
[ -n "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')" ] || cv_fail "expected .token in response got $CV_HTTP_BODY" $LINENO
ALL=$(cat "$CV_HTTP_HEADERS_FILE" "$CV_HTTP_BODY_FILE")
B64=$(printf '%s' "$PASSWORD" | base64 | tr -d '\n=')
B64URL=$(printf '%s' "$B64" | tr '+/' '-_')
for needle in "$PASSWORD" "$B64" "$B64URL"; do
  case "$ALL" in *"$needle"*) cv_fail "expected password (raw/base64) absent from response got it present" $LINENO ;; esac
done
TOKEN_PAYLOAD=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token' | cut -d. -f2 | tr '_-' '/+')
while [ $(( ${#TOKEN_PAYLOAD} % 4 )) -ne 0 ]; do TOKEN_PAYLOAD="${TOKEN_PAYLOAD}="; done
DECODED=$(printf '%s' "$TOKEN_PAYLOAD" | base64 -d 2>/dev/null || true)
case "$DECODED" in *"$PASSWORD"*|*password*) cv_fail "expected token payload without password got $DECODED" $LINENO ;; esac
LEAK=$(printf '%s' "$CV_HTTP_BODY" | jq '[paths | map(tostring) | join(".") | select(test("(?i)pass|hash|salt"))] | length')
[ "$LEAK" = "0" ] || cv_fail "expected no password/hash fields in response got $LEAK" $LINENO
STORED=$(psql -tAc "SELECT password_hash FROM users WHERE email = $(sql_lit "$EMAIL")")
[ -n "$STORED" ] || cv_fail "expected stored account for $EMAIL got none" $LINENO
[ "$STORED" != "$PASSWORD" ] || cv_fail "expected stored password not to be the raw password" $LINENO
case "$STORED" in *"$PASSWORD"*) cv_fail "expected stored hash not to contain the raw password" $LINENO ;; esac

# Cleanup
cv_step Cleanup "delete the created account" $LINENO
delete_users_by_email "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:password_privacy_on_successful_registration"
