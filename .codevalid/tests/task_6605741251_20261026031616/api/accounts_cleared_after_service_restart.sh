#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

# Given
cv_step Given "an account registered, then the service process restarted" $LINENO
register_user restart $LINENO
cv_prereq "restart the app process" $LINENO
restart_app $LINENO

# When
cv_step When "POST /auth/register again with the same email after restart" $LINENO
NEW_PW="After!Restart$(cv_suffix)"
cv_http POST /auth/register "$(register_body "$USER_EMAIL" "After Restart" "$NEW_PW")"

# Then
cv_step Then "registration succeeds (201) because accounts were not persisted across runtimes" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 re-registering $USER_EMAIL after restart got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.email')" = "$USER_EMAIL" ] || cv_fail "expected .user.email=$USER_EMAIL" $LINENO

# Cleanup
cv_step Cleanup "delete accounts created for this email" $LINENO
delete_users_by_email "$USER_EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:accounts_cleared_after_service_restart"
