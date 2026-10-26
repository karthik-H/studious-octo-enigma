#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

# Given
cv_step Given "A unique email and a distinctive password" $LINENO
EMAIL=$(unique_email privacy)
PASSWORD="Pr1vate!Secret$(cv_suffix)"
B64=$(printf '%s' "$PASSWORD" | base64 | tr -d '\n=')

# When
cv_step When "The customer registers via POST /auth/register" $LINENO
cv_http POST /auth/register "$(register_body "$EMAIL" "Private Person" "$PASSWORD")"
RS=$CV_HTTP_STATUS
RB=$CV_HTTP_BODY
RH=$(cat "$CV_HTTP_HEADERS_FILE")

# Then
cv_step Then "Account creation is confirmed and neither body, headers nor token payload reveal the password" $LINENO
[ "$RS" = "201" ] || cv_fail "expected 201 got $RS" $LINENO
[ "$(printf '%s' "$RB" | jq -r '.user.email // empty')" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL in response got $RB" $LINENO
case "$RB$RH" in *"$PASSWORD"*) cv_fail "expected no raw password in response got it" $LINENO ;; esac
case "$RB" in *"$B64"*) cv_fail "expected no base64 password in response got it" $LINENO ;; esac
KEYS=$(printf '%s' "$RB" | jq -r '[paths | map(tostring) | join(".")] | map(select(ascii_downcase | test("password|hash|salt"))) | join(",")')
[ -z "$KEYS" ] || cv_fail "expected no password/hash fields got $KEYS" $LINENO
TOKEN=$(printf '%s' "$RB" | jq -r '.token // empty')
if [ -n "$TOKEN" ]; then
  P=$(printf '%s' "$TOKEN" | cut -d. -f2 | tr '_-' '/+')
  while [ $(( ${#P} % 4 )) -ne 0 ]; do P="$P="; done
  DEC=$(printf '%s' "$P" | base64 -d 2>/dev/null || true)
  echo "token payload: $DEC"
  case "$DEC" in *"$PASSWORD"*) cv_fail "expected token payload without password got it" $LINENO ;; esac
  case "$DEC" in *assword*) cv_fail "expected token payload without password field got $DEC" $LINENO ;; esac
fi

# Cleanup
cv_step Cleanup "No delete API exists; accounts live only in the in-memory store and use unique emails" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:password_privacy_on_successful_registration"
