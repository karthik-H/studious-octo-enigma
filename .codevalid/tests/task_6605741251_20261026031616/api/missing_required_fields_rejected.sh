#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

# Given
cv_step Given "payloads missing email, password, or both" $LINENO
SFX=$(cv_suffix)
EMAIL=$(unique_email missing)
NAME="Missing Fields $SFX"
NO_EMAIL=$(jq -nc --arg n "$NAME" '{name:$n,password:"Str0ng!Password1"}')
NO_PASSWORD=$(jq -nc --arg e "$EMAIL" --arg n "$NAME" '{email:$e,name:$n}')
NO_BOTH=$(jq -nc --arg n "$NAME" '{name:$n}')

# When
cv_step When "POST /auth/register with each incomplete payload" $LINENO
cv_http POST /auth/register "$NO_EMAIL"
S1=$CV_HTTP_STATUS; B1=$CV_HTTP_BODY
cv_http POST /auth/register "$NO_PASSWORD"
S2=$CV_HTTP_STATUS; B2=$CV_HTTP_BODY
cv_http POST /auth/register "$NO_BOTH"
S3=$CV_HTTP_STATUS; B3=$CV_HTTP_BODY

# Then
cv_step Then "each rejected with 400 and an error message; no account created" $LINENO
[ "$S1" = "400" ] || cv_fail "expected 400 when email missing got $S1: $B1" $LINENO
printf '%s' "$B1" | jq -e '.error | test("(?i)email")' >/dev/null || cv_fail "expected error mentioning email got $B1" $LINENO
[ "$S2" = "400" ] || cv_fail "expected 400 when password missing got $S2: $B2" $LINENO
printf '%s' "$B2" | jq -e '.error | test("(?i)password")' >/dev/null || cv_fail "expected error mentioning password got $B2" $LINENO
[ "$S3" = "400" ] || cv_fail "expected 400 when both missing got $S3: $B3" $LINENO
[ -n "$(printf '%s' "$B3" | jq -r '.error // empty')" ] || cv_fail "expected .error when both missing got $B3" $LINENO
[ "$(user_count_by_name "$NAME")" = "0" ] || cv_fail "expected 0 accounts created got $(user_count_by_name "$NAME")" $LINENO

# Cleanup
cv_step Cleanup "remove any account accidentally created" $LINENO
delete_users_by_name "$NAME"
echo "CODEVALID_TEST_ASSERTION_OK:missing_required_fields_rejected"
