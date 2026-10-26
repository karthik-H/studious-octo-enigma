#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5703506414_20261026031616/api/_infra.sh

# Given
cv_step Given "A registered customer exists" $LINENO
register_user login $LINENO
SKU="SKU-LOGIN-$(cv_suffix)"

# When
cv_step When "The customer logs in with correct email and password" $LINENO
cv_http POST /auth/login "$(login_body "$USER_EMAIL" "$USER_PASSWORD")" 200
RESP=$CV_HTTP_BODY

# Then
cv_step Then "A token and public user are returned, no password leaks, and the token permits catalog changes" $LINENO
TOKEN=$(printf "%s" "$RESP" | jq -r ".token // empty")
[ -n "$TOKEN" ] || cv_fail "expected token in login response got $RESP" $LINENO
[ "$(printf "%s" "$RESP" | jq -r ".user.id")" = "$USER_ID" ] || cv_fail "expected user.id $USER_ID got $RESP" $LINENO
[ "$(printf "%s" "$RESP" | jq -r ".user.email")" = "$USER_EMAIL" ] || cv_fail "expected user.email $USER_EMAIL got $RESP" $LINENO
case "$RESP" in *"$USER_PASSWORD"*|*assword*) cv_fail "expected login response without password got $RESP" $LINENO ;; esac
cv_http POST /products "$(product_json "Login product" 12 "$SKU" 4)" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 from POST /products with login token got $CV_HTTP_STATUS" $LINENO
case "$CV_HTTP_BODY" in *"$USER_PASSWORD"*|*assword*) cv_fail "expected product response without password got $CV_HTTP_BODY" $LINENO ;; esac
# Cleanup
cv_step Cleanup "No delete API exists; test data lives only in the in-memory store and uses unique values" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:successful_login_registered_customer"
