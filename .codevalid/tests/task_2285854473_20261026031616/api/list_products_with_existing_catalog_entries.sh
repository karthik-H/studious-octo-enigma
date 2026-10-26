#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2285854473_20261026031616/api/_infra.sh

# Given
cv_step Given "signed-in user adds two products with distinct codes" $LINENO
SFX=$(cv_suffix)
register_user listexisting $LINENO
SKU_A="CVA-$SFX"; SKU_B="CVB-$SFX"
cv_prereq "add product A" $LINENO
create_product "$USER_TOKEN" "$(product_json "Widget A $SFX" "First widget $SFX" 19.99 "$SKU_A" 3)" $LINENO
ID_A=$PRODUCT_ID
cv_prereq "add product B" $LINENO
create_product "$USER_TOKEN" "$(product_json "Widget B $SFX" "Second widget $SFX" 42.5 "$SKU_B" 7)" $LINENO
ID_B=$PRODUCT_ID

# When
cv_step When "signed-in user lists the catalog with GET /products" $LINENO
cv_http GET /products "" 200 -H "Authorization: Bearer $USER_TOKEN"

# Then
cv_step Then "both products are returned with name, description, price and product code" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.products | type == "array"' >/dev/null || cv_fail "expected .products array got $CV_HTTP_BODY" $LINENO
A=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg id "$ID_A" '.products[] | select(.id == $id)')
B=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg id "$ID_B" '.products[] | select(.id == $id)')
[ -n "$A" ] || cv_fail "expected product A ($ID_A) in catalog got none" $LINENO
[ -n "$B" ] || cv_fail "expected product B ($ID_B) in catalog got none" $LINENO
printf '%s' "$A" | jq -e --arg n "Widget A $SFX" --arg d "First widget $SFX" --arg s "$SKU_A" \
  '.name == $n and .description == $d and .price == 19.99 and .sku == $s' >/dev/null \
  || cv_fail "expected product A fields name/description/price 19.99/sku $SKU_A got $A" $LINENO
printf '%s' "$B" | jq -e --arg n "Widget B $SFX" --arg d "Second widget $SFX" --arg s "$SKU_B" \
  '.name == $n and .description == $d and .price == 42.5 and .sku == $s' >/dev/null \
  || cv_fail "expected product B fields name/description/price 42.5/sku $SKU_B got $B" $LINENO

# Cleanup
cv_step Cleanup "products and users live only in app memory; the API has no delete route, nothing to remove" $LINENO
echo "no delete endpoint for products/users; data is in-memory and cleared on app restart"

echo "CODEVALID_TEST_ASSERTION_OK:list_products_with_existing_catalog_entries"
