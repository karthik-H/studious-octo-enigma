#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

# Given
cv_step Given "Payloads missing email, missing password, and missing both" $LINENO
E_NOPW=$(unique_email nopw)
PASSWORD="Str0ng!Pass$(cv_suffix)"
NO_EMAIL=$(jq -nc --arg p "$PASSWORD" '{name:"No Email",password:$p}')
NO_PW=$(jq -nc --arg e "$E_NOPW" '{email:$e,name:"No Password"}')
NONE='{"name":"Nothing"}'

# When
cv_step When "Each payload is sent to POST /auth/register" $LINENO
cv_http POST /auth/register "$NO_EMAIL"; S1=$CV_HTTP_STATUS; B1=$CV_HTTP_BODY
cv_http POST /auth/register "$NO_PW"; S2=$CV_HTTP_STATUS; B2=$CV_HTTP_BODY
cv_http POST /auth/register "$NONE"; S3=$CV_HTTP_STATUS; B3=$CV_HTTP_BODY

# Then
cv_step Then "Each is rejected with 400 and a clear error, and no account is created" $LINENO
[ "$S1" = "400" ] || cv_fail "expected 400 when email missing got $S1" $LINENO
[ "$S2" = "400" ] || cv_fail "expected 400 when password missing got $S2" $LINENO
[ "$S3" = "400" ] || cv_fail "expected 400 when both missing got $S3" $LINENO
printf '%s' "$B1" | jq -r '.error // empty' | grep -qi 'email' || cv_fail "expected error mentioning email got $B1" $LINENO
printf '%s' "$B2" | jq -r '.error // empty' | grep -qi 'password' || cv_fail "expected error mentioning password got $B2" $LINENO
[ -n "$(printf '%s' "$B3" | jq -r '.error // empty')" ] || cv_fail "expected error message when both missing got $B3" $LINENO
cv_http POST /auth/register "$(register_body "$E_NOPW" "No Password" "$PASSWORD")"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering $E_NOPW afterwards (no account from rejected attempt) got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "No delete API exists; accounts live only in the in-memory store and use unique emails" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:missing_required_fields_rejected"
