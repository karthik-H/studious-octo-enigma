#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

# Given
cv_step Given "Malformed email addresses and a valid name and password" $LINENO
S=$(cv_suffix)
PASSWORD="Str0ng!Pass$S"
BAD1="noat$S.example.com"
BAD2="nodomain$S@"
BAD3="nodot$S@example"
BAD4="sp ace$S@example.com"

# When
cv_step When "Each malformed email is sent to POST /auth/register" $LINENO
STATUSES=""
for E in "$BAD1" "$BAD2" "$BAD3" "$BAD4"; do
  cv_http POST /auth/register "$(register_body "$E" "Bad Email" "$PASSWORD")"
  STATUSES="$STATUSES $E=$CV_HTTP_STATUS"
  [ "$CV_HTTP_STATUS" = "400" ] || cv_fail "expected 400 for invalid email $E got $CV_HTTP_STATUS" $LINENO
  ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
  [ -n "$ERR" ] || cv_fail "expected validation error message for $E got $CV_HTTP_BODY" $LINENO
done

# Then
cv_step Then "All were rejected with 400 and no account was created for any of them" $LINENO
echo "statuses:$STATUSES"
for E in "$BAD1" "$BAD3"; do
  login_status "$E" "$PASSWORD"
  [ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 logging in with rejected email $E got $CV_HTTP_STATUS" $LINENO
done

# Cleanup
cv_step Cleanup "No delete API exists; accounts live only in the in-memory store and use unique emails" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:invalid_email_format_rejected"
