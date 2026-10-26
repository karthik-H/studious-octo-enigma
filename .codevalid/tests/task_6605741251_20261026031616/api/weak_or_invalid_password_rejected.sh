#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

# Given
cv_step Given "Unique valid emails paired with an empty and a too-short password" $LINENO
E_EMPTY=$(unique_email pwempty)
E_SHORT=$(unique_email pwshort)

# When
cv_step When "Both registrations are sent to POST /auth/register" $LINENO
cv_http POST /auth/register "$(register_body "$E_EMPTY" "Weak Pw" "")"
S_EMPTY=$CV_HTTP_STATUS
B_EMPTY=$CV_HTTP_BODY
cv_http POST /auth/register "$(register_body "$E_SHORT" "Weak Pw" "abc12")"
S_SHORT=$CV_HTTP_STATUS
B_SHORT=$CV_HTTP_BODY

# Then
cv_step Then "Both are rejected with 400 and an error, and neither email was registered" $LINENO
[ "$S_EMPTY" = "400" ] || cv_fail "expected 400 for empty password got $S_EMPTY" $LINENO
[ "$S_SHORT" = "400" ] || cv_fail "expected 400 for short password got $S_SHORT" $LINENO
[ -n "$(printf '%s' "$B_EMPTY" | jq -r '.error // empty')" ] || cv_fail "expected error message for empty password got $B_EMPTY" $LINENO
[ -n "$(printf '%s' "$B_SHORT" | jq -r '.error // empty')" ] || cv_fail "expected error message for short password got $B_SHORT" $LINENO
for E in "$E_EMPTY" "$E_SHORT"; do
  cv_http POST /auth/register "$(register_body "$E" "Weak Pw" "Str0ng!Pass$(cv_suffix)")"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering $E with a valid password (no account from rejected attempt) got $CV_HTTP_STATUS" $LINENO
done

# Cleanup
cv_step Cleanup "No delete API exists; accounts live only in the in-memory store and use unique emails" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:weak_or_invalid_password_rejected"
