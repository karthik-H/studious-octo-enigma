#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5703506414_20261026031616/api/_infra.sh

# Given
cv_step Given "Credentials that match no registered account" $LINENO
EMAIL="nobody.$(cv_suffix)@example.com"
SKU="SKU-BADCRED-$(cv_suffix)"

# When
cv_step When "Sign-in is attempted and then POST /products is sent without a session" $LINENO
cv_http POST /auth/login "$(login_body "$EMAIL" "WrongPass123!")"
LS=$CV_HTTP_STATUS
LTOK=$(printf "%s" "$CV_HTTP_BODY" | jq -r ".token // empty" 2>/dev/null || true)
cv_http POST /products "$(product_json "Bad cred product" 7 "$SKU" 1)" -H "Authorization: Bearer ${LTOK:-none}"
PS=$CV_HTTP_STATUS

# Then
cv_step Then "Sign-in fails with no token and the product request is rejected" $LINENO
[ "$LS" = "401" ] || cv_fail "expected 401 from POST /auth/login got $LS" $LINENO
[ -z "$LTOK" ] || cv_fail "expected no token on failed login got $LTOK" $LINENO
case "$PS" in 401|403) ;; *) cv_fail "expected 401/403 from POST /products got $PS" $LINENO ;; esac
N=$(count_sku "$SKU")
[ "$N" = "0" ] || cv_fail "expected 0 products with sku $SKU got $N" $LINENO
# Cleanup
cv_step Cleanup "No delete API exists; test data lives only in the in-memory store and uses unique values" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:invalid_credentials_then_post_products_blocked"
