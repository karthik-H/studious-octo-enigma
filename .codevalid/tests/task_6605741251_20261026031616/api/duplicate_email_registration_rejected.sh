#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

# Given
cv_step Given "an account already registered with a unique email" $LINENO
register_user dup $LINENO
OTHER_PW="Other!Pass$(cv_suffix)"
UPPER=$(printf '%s' "$USER_EMAIL" | tr '[:lower:]' '[:upper:]')

# When
cv_step When "POST /auth/register again with the same email (exact and upper-cased)" $LINENO
cv_http POST /auth/register "$(register_body "$USER_EMAIL" "Second Person" "$OTHER_PW")"
S1=$CV_HTTP_STATUS; B1=$CV_HTTP_BODY
cv_http POST /auth/register "$(register_body "$UPPER" "Second Person" "$OTHER_PW")"
S2=$CV_HTTP_STATUS; B2=$CV_HTTP_BODY

# Then
cv_step Then "both duplicates rejected with an error and no second account created" $LINENO
[ "$S1" = "409" ] || cv_fail "expected 409 for duplicate email got $S1: $B1" $LINENO
[ -n "$(printf '%s' "$B1" | jq -r '.error // empty')" ] || cv_fail "expected .error in duplicate response got $B1" $LINENO
[ -z "$(printf '%s' "$B1" | jq -r '.token // empty')" ] || cv_fail "expected no token in duplicate response got one" $LINENO
[ -z "$(printf '%s' "$B1" | jq -r '.user.id // empty')" ] || cv_fail "expected no user in duplicate response got one" $LINENO
[ "$S2" = "409" ] || cv_fail "expected 409 for upper-cased duplicate email got $S2: $B2" $LINENO
[ -n "$(printf '%s' "$B2" | jq -r '.error // empty')" ] || cv_fail "expected .error in upper-case duplicate response got $B2" $LINENO
N=$(user_count_by_email "$USER_EMAIL")
[ "$N" = "1" ] || cv_fail "expected exactly 1 account for $USER_EMAIL got $N" $LINENO
[ "$(psql -tAc "SELECT name FROM users WHERE id = $(sql_lit "$USER_ID")")" = "Test User" ] || cv_fail "expected original account unchanged (name Test User)" $LINENO

# Cleanup
cv_step Cleanup "delete the created account" $LINENO
delete_users_by_email "$USER_EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:duplicate_email_registration_rejected"
