#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5703506414_20261026031616/api/_infra.sh

# Given
cv_step Given "An email that no account uses and a registered account for comparison" $LINENO
register_user known $LINENO
EMAIL="unregistered.$(cv_suffix)@example.com"
PW="SomePass123!$(cv_suffix)"

# When
cv_step When "Login is attempted with the unregistered email and with a known email plus wrong password" $LINENO
cv_http POST /auth/login "$(login_body "$EMAIL" "$PW")"
S1=$CV_HTTP_STATUS; R1=$CV_HTTP_BODY
cv_http POST /auth/login "$(login_body "$USER_EMAIL" "$PW")"
S2=$CV_HTTP_STATUS; R2=$CV_HTTP_BODY

# Then
cv_step Then "Unregistered login fails with 401, no token, no account hint, and no account is created" $LINENO
[ "$S1" = "401" ] || cv_fail "expected 401 for unregistered email got $S1" $LINENO
[ -z "$(printf "%s" "$R1" | jq -r ".token // empty")" ] || cv_fail "expected no token got $R1" $LINENO
case "$R1" in *"$PW"*) cv_fail "expected no password echo got $R1" $LINENO ;; esac
[ "$R1" = "$R2" ] && [ "$S1" = "$S2" ] || cv_fail "expected identical failure for unknown vs known email got $S1 $R1 vs $S2 $R2" $LINENO
cv_http POST /auth/login "$(login_body "$EMAIL" "$PW")"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected unregistered email to still fail (no account created) got $CV_HTTP_STATUS" $LINENO
cv_http POST /products "$(product_json "Unreg product" 3 "SKU-UNREG-$(cv_suffix)" 1)"
case "$CV_HTTP_STATUS" in 401|403) ;; *) cv_fail "expected 401/403 from POST /products got $CV_HTTP_STATUS" $LINENO ;; esac
# Cleanup
cv_step Cleanup "No delete API exists; test data lives only in the in-memory store and uses unique values" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:login_unregistered_email"
