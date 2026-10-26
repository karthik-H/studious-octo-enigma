#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

# Given
cv_step Given "unique emails paired with empty and too-short passwords" $LINENO
E_EMPTY=$(unique_email weakempty)
E_SHORT=$(unique_email weakshort)
E_MISSING=$(unique_email weaknum)

# When
cv_step When "POST /auth/register with an empty, a 5-char and a non-string password" $LINENO
cv_http POST /auth/register "$(register_body "$E_EMPTY" "Weak Pw" "")"
S1=$CV_HTTP_STATUS; B1=$CV_HTTP_BODY
cv_http POST /auth/register "$(register_body "$E_SHORT" "Weak Pw" "abc12")"
S2=$CV_HTTP_STATUS; B2=$CV_HTTP_BODY
cv_http POST /auth/register "$(jq -nc --arg e "$E_MISSING" '{email:$e,name:"Weak Pw",password:1234567}')"
S3=$CV_HTTP_STATUS; B3=$CV_HTTP_BODY

# Then
cv_step Then "each rejected with 400 validation error and no accounts created" $LINENO
[ "$S1" = "400" ] || cv_fail "expected 400 for empty password got $S1: $B1" $LINENO
[ -n "$(printf '%s' "$B1" | jq -r '.error // empty')" ] || cv_fail "expected .error for empty password got $B1" $LINENO
[ "$S2" = "400" ] || cv_fail "expected 400 for short password got $S2: $B2" $LINENO
[ -n "$(printf '%s' "$B2" | jq -r '.error // empty')" ] || cv_fail "expected .error for short password got $B2" $LINENO
[ "$S3" = "400" ] || cv_fail "expected 400 for non-string password got $S3: $B3" $LINENO
for E in "$E_EMPTY" "$E_SHORT" "$E_MISSING"; do
  [ "$(user_count_by_email "$E")" = "0" ] || cv_fail "expected no account for $E got one" $LINENO
done

# Cleanup
cv_step Cleanup "remove any account accidentally created" $LINENO
delete_users_by_email "$E_EMPTY" "$E_SHORT" "$E_MISSING"
echo "CODEVALID_TEST_ASSERTION_OK:weak_or_invalid_password_rejected"
