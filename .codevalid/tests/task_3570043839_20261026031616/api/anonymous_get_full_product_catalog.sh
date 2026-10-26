#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3570043839_20261026031616/api/_infra.sh

# Given
cv_step Given "two products exist in the catalog (created by a signed-in seller)" $LINENO
seed_product "fullcat-a" $LINENO
ID_A=$PRODUCT_ID; SKU_A=$SEED_SKU; NAME_A=$SEED_NAME
seed_product "fullcat-b" $LINENO
ID_B=$PRODUCT_ID; SKU_B=$SEED_SKU

# When
cv_step When "an anonymous client requests GET /products without any credentials" $LINENO
cv_http GET /products

# Then
cv_step Then "200 with a products array containing every created product and its fields" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.products | type')" = "array" ] || cv_fail "expected .products array got $CV_HTTP_BODY" $LINENO
for id in "$ID_A" "$ID_B"; do
  n=$(printf '%s' "$CV_HTTP_BODY" | jq --arg i "$id" '[.products[] | select(.id == $i)] | length')
  [ "$n" = "1" ] || cv_fail "expected product $id exactly once in catalog got $n" $LINENO
done
row=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg i "$ID_A" '.products[] | select(.id == $i)')
[ "$(printf '%s' "$row" | jq -r '.name')" = "$NAME_A" ] || cv_fail "expected name $NAME_A got $row" $LINENO
[ "$(printf '%s' "$row" | jq -r '.sku')" = "$SKU_A" ] || cv_fail "expected sku $SKU_A got $row" $LINENO
[ "$(printf '%s' "$row" | jq -r '.price')" = "19.99" ] || cv_fail "expected price 19.99 got $row" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg i "$ID_B" '.products[] | select(.id == $i) | .sku')" = "$SKU_B" ] || cv_fail "expected sku $SKU_B for $ID_B" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove through the API" $LINENO
cv_no_delete_note
echo "CODEVALID_TEST_ASSERTION_OK:anonymous_get_full_product_catalog"
