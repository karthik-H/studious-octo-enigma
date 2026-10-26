#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5703506414_20261026031616/api/_infra.sh

# Given
cv_step Given "A customer has logged in and the token works" $LINENO
register_user lifetime $LINENO
login_user "$USER_EMAIL" "$USER_PASSWORD" $LINENO
TOKEN=$LOGIN_TOKEN
cv_http POST /products "$(product_json "Pre restart" 2 "SKU-LPRE-$(cv_suffix)" 1)" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 with fresh token got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "The service restarts and the old token and credentials are reused" $LINENO
restart_app $LINENO
SKU="SKU-LPOST-$(cv_suffix)"
cv_http POST /products "$(product_json "Post restart" 2 "$SKU" 1)" -H "Authorization: Bearer $TOKEN"
PS=$CV_HTTP_STATUS
cv_http POST /auth/login "$(login_body "$USER_EMAIL" "$USER_PASSWORD")"
LS=$CV_HTTP_STATUS

# Then
cv_step Then "The token is rejected and the account no longer exists" $LINENO
case "$PS" in 401|403) ;; *) cv_fail "expected 401/403 for pre-restart token got $PS" $LINENO ;; esac
[ "$LS" = "401" ] || cv_fail "expected 401 login after restart (account not retained) got $LS" $LINENO
N=$(count_sku "$SKU")
[ "$N" = "0" ] || cv_fail "expected 0 products with sku $SKU got $N" $LINENO
# Cleanup
cv_step Cleanup "No delete API exists; test data lives only in the in-memory store and uses unique values" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:login_service_restart_session_lifetime"
