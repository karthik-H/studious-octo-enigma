#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

# Given
cv_step Given "An account registered in the current runtime whose email is now taken" $LINENO
register_user restart $LINENO
cv_http POST /auth/register "$(register_body "$USER_EMAIL" "Again" "$USER_PASSWORD")"
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 re-registering before restart got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "The service restarts and the same email is registered again" $LINENO
restart_app $LINENO
NEW_PW="After!Restart$(cv_suffix)"
cv_http POST /auth/register "$(register_body "$USER_EMAIL" "After Restart" "$NEW_PW")"
RS=$CV_HTTP_STATUS
RB=$CV_HTTP_BODY

# Then
cv_step Then "The registration succeeds with 201 as a new account" $LINENO
[ "$RS" = "201" ] || cv_fail "expected 201 registering same email after restart got $RS: $RB" $LINENO
NID=$(printf '%s' "$RB" | jq -r '.user.id // empty')
[ -n "$NID" ] && [ "$NID" != "$USER_ID" ] || cv_fail "expected a new user id different from $USER_ID got $NID" $LINENO
login_status "$USER_EMAIL" "$USER_PASSWORD"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 with pre-restart password got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "No delete API exists; accounts live only in the in-memory store and use unique emails" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:accounts_cleared_after_service_restart"
