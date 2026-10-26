#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

# Given
cv_step Given "a set of improperly formatted emails and a valid password" $LINENO
SFX=$(cv_suffix)
PASSWORD="Str0ng!Pass$SFX"
NAME="Bad Email $SFX"
BAD_EMAILS=("noat$SFX.example.com" "nodomain$SFX@" "user$SFX@nodot" "@$SFX.example.com" "sp ace$SFX@example.com")

# When
cv_step When "POST /auth/register with each invalid email" $LINENO
STATUSES=(); BODIES=()
for E in "${BAD_EMAILS[@]}"; do
  cv_http POST /auth/register "$(register_body "$E" "$NAME" "$PASSWORD")"
  STATUSES+=("$CV_HTTP_STATUS"); BODIES+=("$CV_HTTP_BODY")
done

# Then
cv_step Then "each request rejected with 400 validation error and no account created" $LINENO
for i in "${!BAD_EMAILS[@]}"; do
  [ "${STATUSES[$i]}" = "400" ] || cv_fail "expected 400 for email '${BAD_EMAILS[$i]}' got ${STATUSES[$i]}: ${BODIES[$i]}" $LINENO
  [ -n "$(printf '%s' "${BODIES[$i]}" | jq -r '.error // empty')" ] || cv_fail "expected .error for email '${BAD_EMAILS[$i]}' got ${BODIES[$i]}" $LINENO
done
N=$(user_count_by_name "$NAME")
[ "$N" = "0" ] || cv_fail "expected 0 accounts created for invalid emails got $N" $LINENO

# Cleanup
cv_step Cleanup "remove any account accidentally created" $LINENO
delete_users_by_name "$NAME"
echo "CODEVALID_TEST_ASSERTION_OK:invalid_email_format_rejected"
