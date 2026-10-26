#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5703506414_20261026031616/api/_infra.sh

# Given
cv_step Given "A signed-in customer has created a product with its token" $LINENO
register_user restart $LINENO
login_user "$USER_EMAIL" "$USER_PASSWORD" $LINENO
TOKEN=$LOGIN_TOKEN
cv_http POST /products "$(product_json "Before restart" 4 "SKU-PRE-$(cv_suffix)" 1)" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 from POST /products before restart got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "The service restarts and the old token is reused for POST /products" $LINENO
restart_app $LINENO
SKU="SKU-POST-$(cv_suffix)"
cv_http POST /products "$(product_json "After restart" 4 "$SKU" 1)" -H "Authorization: Bearer $TOKEN"
PS=$CV_HTTP_STATUS
cv_http POST /auth/login "$(login_body "$USER_EMAIL" "$USER_PASSWORD")"
LS=$CV_HTTP_STATUS

# Then
cv_step Then "The old session is rejected, no product is created and the account is gone" $LINENO
case "$PS" in 401|403) ;; *) cv_fail "expected 401/403 with pre-restart token got $PS" $LINENO ;; esac
N=$(count_sku "$SKU")
[ "$N" = "0" ] || cv_fail "expected 0 products with sku $SKU got $N" $LINENO
[ "$LS" = "401" ] || cv_fail "expected 401 logging in with pre-restart account got $LS" $LINENO
# Cleanup
cv_step Cleanup "No delete API exists; test data lives only in the in-memory store and uses unique values" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:session_lifetime_service_restart"
