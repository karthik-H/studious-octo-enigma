#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

# Given
cv_step Given "An account already registered with a unique email" $LINENO
register_user dup $LINENO
OTHER_PW="Other!Pass$(cv_suffix)"

# When
cv_step When "A second registration is sent with the same email (different case) and another password" $LINENO
UPPER=$(printf '%s' "$USER_EMAIL" | tr '[:lower:]' '[:upper:]')
cv_http POST /auth/register "$(register_body "$UPPER" "Second Person" "$OTHER_PW")"
RS=$CV_HTTP_STATUS
RB=$CV_HTTP_BODY
cv_http POST /auth/register "$(register_body "$USER_EMAIL" "Second Person" "$OTHER_PW")"
RS2=$CV_HTTP_STATUS
RB2=$CV_HTTP_BODY

# Then
cv_step Then "Both duplicates are rejected with an error and no second account is created" $LINENO
[ "$RS" = "409" ] || cv_fail "expected 409 for duplicate email (different case) got $RS" $LINENO
[ "$RS2" = "409" ] || cv_fail "expected 409 for duplicate email got $RS2" $LINENO
ERR=$(printf '%s' "$RB2" | jq -r '.error // empty')
[ -n "$ERR" ] || cv_fail "expected an error message for duplicate got $RB2" $LINENO
T=$(printf '%s' "$RB2" | jq -r '.token // empty')
[ -z "$T" ] || cv_fail "expected no token on duplicate registration got one" $LINENO
login_status "$USER_EMAIL" "$OTHER_PW"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 with duplicate's password (no second account) got $CV_HTTP_STATUS" $LINENO
login_status "$USER_EMAIL" "$USER_PASSWORD"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected original account still login 200 got $CV_HTTP_STATUS" $LINENO
OID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ "$OID" = "$USER_ID" ] || cv_fail "expected original user id $USER_ID got $OID" $LINENO

# Cleanup
cv_step Cleanup "No delete API exists; accounts live only in the in-memory store and use unique emails" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:duplicate_email_registration_rejected"
