#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5703506414_20261026031616/api/_infra.sh

# Given
cv_step Given "A registered customer exists" $LINENO
register_user signin $LINENO
SKU="SKU-SIGNIN-$(cv_suffix)"

# When
cv_step When "The customer signs in and POSTs a new product with the login token" $LINENO
login_user "$USER_EMAIL" "$USER_PASSWORD" $LINENO
cv_http POST /products "$(product_json "Signed-in product" 19.99 "$SKU" 3)" -H "Authorization: Bearer $LOGIN_TOKEN"

# Then
cv_step Then "The product is created and appears in the catalog" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 from POST /products got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
PID=$(printf "%s" "$CV_HTTP_BODY" | jq -r ".product.id // empty")
[ -n "$PID" ] || cv_fail "expected product.id in response got $CV_HTTP_BODY" $LINENO
[ "$(printf "%s" "$CV_HTTP_BODY" | jq -r .product.sku)" = "$SKU" ] || cv_fail "expected product.sku $SKU got $CV_HTTP_BODY" $LINENO
[ "$(printf "%s" "$CV_HTTP_BODY" | jq -r .product.price)" = "19.99" ] || cv_fail "expected product.price 19.99 got $CV_HTTP_BODY" $LINENO
cv_http GET "/products/$PID" 200
[ "$(printf "%s" "$CV_HTTP_BODY" | jq -r .product.name)" = "Signed-in product" ] || cv_fail "expected stored product name got $CV_HTTP_BODY" $LINENO
# Cleanup
cv_step Cleanup "No delete API exists; test data lives only in the in-memory store and uses unique values" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:signed_in_customer_catalog_change"
