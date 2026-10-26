#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

# Given
cv_step Given "A unique email, a name and a valid password that are not yet registered" $LINENO
EMAIL=$(unique_email happy)
PASSWORD="Str0ng!Pass$(cv_suffix)"

# When
cv_step When "The customer registers via POST /auth/register" $LINENO
cv_http POST /auth/register "$(register_body "$EMAIL" "Happy Customer" "$PASSWORD")"
RS=$CV_HTTP_STATUS
RB=$CV_HTTP_BODY

# Then
cv_step Then "201 with the public user and no password; the account exists and the email is now unique" $LINENO
[ "$RS" = "201" ] || cv_fail "expected 201 from register got $RS: $RB" $LINENO
GOT_EMAIL=$(printf '%s' "$RB" | jq -r '.user.email // empty')
[ "$GOT_EMAIL" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL got $GOT_EMAIL" $LINENO
UID_=$(printf '%s' "$RB" | jq -r '.user.id // empty')
[ -n "$UID_" ] || cv_fail "expected user.id in response got $RB" $LINENO
NAME=$(printf '%s' "$RB" | jq -r '.user.name // empty')
[ "$NAME" = "Happy Customer" ] || cv_fail "expected user.name Happy Customer got $NAME" $LINENO
case "$RB" in *"$PASSWORD"*) cv_fail "expected response without the raw password got it in body" $LINENO ;; esac
HASPW=$(printf '%s' "$RB" | jq '[paths | map(tostring) | join(".") | ascii_downcase | select(test("password"))] | length')
[ "$HASPW" = "0" ] || cv_fail "expected no password fields in response got $HASPW" $LINENO
login_status "$EMAIL" "$PASSWORD"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 logging in with new account got $CV_HTTP_STATUS" $LINENO
cv_http POST /auth/register "$(register_body "$EMAIL" "Happy Customer" "$PASSWORD")"
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 on re-registering same email (uniqueness) got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "No delete API exists; accounts live only in the in-memory store and use unique emails" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:successful_registration_new_email"
