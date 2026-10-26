#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2285854473_20261026031616/api/_infra.sh

# Given
cv_step Given "signed-in user has already added a product with a unique product code (sku)" $LINENO
cv_prereq "register user" $LINENO
register_user dupcode $LINENO
SFX=$(cv_suffix)
SKU="CV-DUP-$SFX"
cv_prereq "create first product with sku $SKU" $LINENO
cv_http POST /products "$(product_json "Original $SFX" 12.5 "$SKU" 4)" -H "Authorization: Bearer $REG_TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating first product got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
FIRST_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$FIRST_ID" ] || cv_fail "expected product.id in first create response got $CV_HTTP_BODY" $LINENO

# When
cv_step When "POST /products again with the same product code" $LINENO
cv_http POST /products "$(product_json "Copy $SFX" 20 "$SKU" 1)" -H "Authorization: Bearer $REG_TOKEN"

# Then
cv_step Then "second request is rejected with a uniqueness error and no duplicate exists" $LINENO
DUP_STATUS="$CV_HTTP_STATUS"
DUP_BODY="$CV_HTTP_BODY"
COUNT=$(db_count_sku "$SKU")
[ "$DUP_STATUS" = "409" ] || cv_fail "expected 409 uniqueness error for duplicate product code got $DUP_STATUS: $DUP_BODY (products with sku now: $COUNT)" $LINENO
ERR=$(printf '%s' "$DUP_BODY" | jq -r '.error // empty' 2>/dev/null || true)
[ -n "$ERR" ] || cv_fail "expected an error message in duplicate response got $DUP_BODY" $LINENO
[ "$COUNT" = "1" ] || cv_fail "expected exactly 1 product with sku $SKU got $COUNT" $LINENO
cv_http GET "/products/$FIRST_ID" "" 200
NAME=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.name // empty')
[ "$NAME" = "Original $SFX" ] || cv_fail "expected original product unchanged (name 'Original $SFX') got '$NAME'" $LINENO

# Cleanup
cv_step Cleanup "remove products and user created by this test" $LINENO
db_cleanup_sku "$SKU"
db_cleanup_user "$USER_ID"

echo "CODEVALID_TEST_ASSERTION_OK:add_product_duplicate_code_error"
