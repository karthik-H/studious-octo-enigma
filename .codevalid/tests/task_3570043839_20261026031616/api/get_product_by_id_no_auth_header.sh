#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3570043839_20261026031616/api/_infra.sh

# Given
cv_step Given "an existing product created by a signed-in seller" $LINENO
seed_product "get_product_by_id_no_auth_header" $LINENO

# When
cv_step When "an anonymous client (no Authorization header, no cookie) requests GET /products/{id}" $LINENO
cv_http GET "/products/$PRODUCT_ID"

# Then
cv_step Then "200 with the product's details (id, name, description, price, sku, stock)" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
p=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product // empty')
[ -n "$p" ] || cv_fail "expected .product object got $CV_HTTP_BODY" $LINENO
[ "$(printf '%s' "$p" | jq -r '.id')" = "$PRODUCT_ID" ] || cv_fail "expected id $PRODUCT_ID got $p" $LINENO
[ "$(printf '%s' "$p" | jq -r '.name')" = "$SEED_NAME" ] || cv_fail "expected name $SEED_NAME got $p" $LINENO
[ "$(printf '%s' "$p" | jq -r '.sku')" = "$SEED_SKU" ] || cv_fail "expected sku $SEED_SKU got $p" $LINENO
[ "$(printf '%s' "$p" | jq -r '.price')" = "19.99" ] || cv_fail "expected price 19.99 got $p" $LINENO
[ "$(printf '%s' "$p" | jq -r '.stock')" = "7" ] || cv_fail "expected stock 7 (availability) got $p" $LINENO
printf '%s' "$p" | jq -e '.description | type == "string" and length > 0' >/dev/null || cv_fail "expected non-empty description got $p" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove through the API" $LINENO
cv_no_delete_note
echo "CODEVALID_TEST_ASSERTION_OK:get_product_by_id_no_auth_header"
