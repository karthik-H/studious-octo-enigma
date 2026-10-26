#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5703506414_20261026031616/api/_infra.sh

# Given
cv_step Given "A registered customer exists" $LINENO
register_user badpw $LINENO
WRONG="Wr0ngPassword!$(cv_suffix)"
SKU="SKU-BADPW-$(cv_suffix)"

# When
cv_step When "Login is attempted with the right email and a wrong password" $LINENO
cv_http POST /auth/login "$(login_body "$USER_EMAIL" "$WRONG")"
LS=$CV_HTTP_STATUS
RESP=$CV_HTTP_BODY

# Then
cv_step Then "Login is rejected without token or password echo, and catalog changes stay blocked" $LINENO
[ "$LS" = "401" ] || cv_fail "expected 401 from POST /auth/login got $LS" $LINENO
[ -z "$(printf "%s" "$RESP" | jq -r ".token // empty")" ] || cv_fail "expected no token got $RESP" $LINENO
case "$RESP" in *"$WRONG"*|*"$USER_PASSWORD"*|*passwordHash*) cv_fail "expected no password in error got $RESP" $LINENO ;; esac
cv_http POST /products "$(product_json "Bad pw product" 3 "$SKU" 1)"
case "$CV_HTTP_STATUS" in 401|403) ;; *) cv_fail "expected 401/403 from POST /products without session got $CV_HTTP_STATUS" $LINENO ;; esac
N=$(count_sku "$SKU")
[ "$N" = "0" ] || cv_fail "expected 0 products with sku $SKU got $N" $LINENO
# Cleanup
cv_step Cleanup "No delete API exists; test data lives only in the in-memory store and uses unique values" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:login_invalid_password_existing_email"
