#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5703506414_20261026031616/api/_infra.sh

# Given
cv_step Given "A registered customer exists and a set of malformed login payloads" $LINENO
register_user malformed $LINENO
SECRET_PW="Leaky!$(cv_suffix)"

# When
cv_step When "POST /auth/login is called with missing email, missing password, empty body and a malformed email" $LINENO
cv_http POST /auth/login "$(jq -nc --arg p "$SECRET_PW" "{password:\$p}")"
S1=$CV_HTTP_STATUS; R1=$CV_HTTP_BODY
cv_http POST /auth/login "$(jq -nc --arg e "$USER_EMAIL" "{email:\$e}")"
S2=$CV_HTTP_STATUS; R2=$CV_HTTP_BODY
cv_http POST /auth/login "{}"
S3=$CV_HTTP_STATUS; R3=$CV_HTTP_BODY
cv_http POST /auth/login "$(login_body "not-an-email" "$SECRET_PW")"
S4=$CV_HTTP_STATUS; R4=$CV_HTTP_BODY

# Then
cv_step Then "Each is a 400 without token or password, and catalog changes stay blocked" $LINENO
for P in "missing-email:$S1" "missing-password:$S2" "empty-body:$S3" "malformed-email:$S4"; do
  [ "${P#*:}" = "400" ] || cv_fail "expected 400 for ${P%%:*} got ${P#*:}" $LINENO
done
for R in "$R1" "$R2" "$R3" "$R4"; do
  [ -z "$(printf "%s" "$R" | jq -r ".token // empty" 2>/dev/null)" ] || cv_fail "expected no token got $R" $LINENO
  case "$R" in *"$SECRET_PW"*|*"$USER_PASSWORD"*) cv_fail "expected no password echo got $R" $LINENO ;; esac
done
cv_http POST /products "$(product_json "Malformed product" 3 "SKU-MAL-$(cv_suffix)" 1)"
case "$CV_HTTP_STATUS" in 401|403) ;; *) cv_fail "expected 401/403 from POST /products got $CV_HTTP_STATUS" $LINENO ;; esac
# Cleanup
cv_step Cleanup "No delete API exists; test data lives only in the in-memory store and uses unique values" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:login_missing_or_malformed_credentials"
