#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2285854473_20261026031616/api/_infra.sh

# Given
cv_step Given "a signed-in user and a unique product payload" $LINENO
SFX=$(cv_suffix)
SKU="CVS-$SFX"
register_user addok $LINENO
BODY=$(product_json "Lamp $SFX" "Desk lamp $SFX" 29.95 "$SKU" 4)

# When
cv_step When "the user adds the product with POST /products" $LINENO
cv_http POST /products "$BODY" -H "Authorization: Bearer $USER_TOKEN"
CREATE_STATUS=$CV_HTTP_STATUS; CREATE_BODY=$CV_HTTP_BODY

# Then
cv_step Then "201 with the product, and it is browseable via GET /products and GET /products/:id" $LINENO
[ "$CREATE_STATUS" = "201" ] || cv_fail "expected 201 got $CREATE_STATUS: $CREATE_BODY" $LINENO
PID=$(printf '%s' "$CREATE_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product.id in response got $CREATE_BODY" $LINENO
printf '%s' "$CREATE_BODY" | jq -e --arg n "Lamp $SFX" --arg d "Desk lamp $SFX" --arg s "$SKU" \
  '.product.name == $n and .product.description == $d and .product.price == 29.95 and .product.sku == $s' >/dev/null \
  || cv_fail "expected created product to echo name/description/price/sku got $CREATE_BODY" $LINENO
cv_http GET /products "" 200
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$PID" --arg s "$SKU" 'any(.products[]; .id == $id and .sku == $s and .price == 29.95)' >/dev/null \
  || cv_fail "expected product $PID in GET /products got $CV_HTTP_BODY" $LINENO
cv_http GET "/products/$PID" "" 200
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$PID" '.product.id == $id' >/dev/null || cv_fail "expected GET /products/$PID to return it got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "products and users live only in app memory; the API has no delete route, nothing to remove" $LINENO
echo "no delete endpoint for products/users; data is in-memory and cleared on app restart"

echo "CODEVALID_TEST_ASSERTION_OK:add_product_success_visible_in_catalog"
