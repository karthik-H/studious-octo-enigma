#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2285854473_20261026031616/api/_infra.sh

# Given
cv_step Given "a signed-in user adds a product so the catalog is non-empty" $LINENO
SFX=$(cv_suffix)
SKU="CVU-$SFX"
register_user unauthget $LINENO
create_product "$USER_TOKEN" "$(product_json "Public item $SFX" "Browsable $SFX" 9.5 "$SKU" 1)" $LINENO
PID=$PRODUCT_ID

# When
cv_step When "an unsigned client calls GET /products without any credentials" $LINENO
cv_http GET /products
STATUS1=$CV_HTTP_STATUS; BODY1=$CV_HTTP_BODY
cv_http GET /products "" -H "Authorization: Bearer $USER_TOKEN"
STATUS2=$CV_HTTP_STATUS
cv_http POST /products "$(product_json "Anon $SFX" "anon" 1 "CVX-$SFX" 1)"
POST_STATUS=$CV_HTTP_STATUS

# Then
cv_step Then "read-only browsing is allowed (200 catalog) while changes stay restricted (401)" $LINENO
[ "$STATUS1" = "200" ] || cv_fail "expected unauthenticated GET /products 200 got $STATUS1" $LINENO
[ "$STATUS2" = "200" ] || cv_fail "expected authenticated GET /products 200 got $STATUS2" $LINENO
printf '%s' "$BODY1" | jq -e --arg id "$PID" '.products | type == "array" and any(.[]; .id == $id)' >/dev/null \
  || cv_fail "expected unauthenticated catalog to contain product $PID got $BODY1" $LINENO
[ "$POST_STATUS" = "401" ] || cv_fail "expected unauthenticated POST /products 401 got $POST_STATUS" $LINENO

# Cleanup
cv_step Cleanup "products and users live only in app memory; the API has no delete route, nothing to remove" $LINENO
echo "no delete endpoint for products/users; data is in-memory and cleared on app restart"

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_get_products_access_control"
