#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

# Given
cv_step Given "a new unique email and a valid password not yet registered" $LINENO
EMAIL=$(unique_email happy)
PASSWORD="Str0ng!Pass$(cv_suffix)"
[ "$(user_count_by_email "$EMAIL")" = "0" ] || cv_fail "expected no existing account for $EMAIL" $LINENO

# When
cv_step When "POST /auth/register with the new email, a name and the password" $LINENO
cv_http POST /auth/register "$(register_body "$EMAIL" "Happy Customer" "$PASSWORD")"

# Then
cv_step Then "201 with the created user, no password exposed, account stored, email unique" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
USER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ -n "$USER_ID" ] || cv_fail "expected .user.id in response got $CV_HTTP_BODY" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.email')" = "$EMAIL" ] || cv_fail "expected .user.email=$EMAIL got $(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.email')" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.name')" = "Happy Customer" ] || cv_fail "expected .user.name=Happy Customer got $(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.name')" $LINENO
case "$CV_HTTP_BODY" in *"$PASSWORD"*) cv_fail "expected raw password absent from response got it present" $LINENO ;; esac
LEAK=$(printf '%s' "$CV_HTTP_BODY" | jq '[paths | map(tostring) | join(".") | select(test("(?i)password"))] | length')
[ "$LEAK" = "0" ] || cv_fail "expected no password-like fields in response got $LEAK" $LINENO
[ "$(user_count_by_email "$EMAIL")" = "1" ] || cv_fail "expected exactly 1 stored account for $EMAIL got $(user_count_by_email "$EMAIL")" $LINENO
cv_prereq "re-register same email to confirm uniqueness is enforced" $LINENO
cv_http POST /auth/register "$(register_body "$EMAIL" "Happy Customer" "$PASSWORD")"
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 on duplicate registration got $CV_HTTP_STATUS" $LINENO
[ "$(user_count_by_email "$EMAIL")" = "1" ] || cv_fail "expected still 1 account for $EMAIL got $(user_count_by_email "$EMAIL")" $LINENO

# Cleanup
cv_step Cleanup "delete the created account" $LINENO
delete_users_by_email "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:successful_registration_new_email"
