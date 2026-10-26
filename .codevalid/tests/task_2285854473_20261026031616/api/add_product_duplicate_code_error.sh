#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2285854473_20261026031616/api/_infra.sh

# Given
cv_step Given "a signed-in user has already added a product with a given code" $LINENO
SFX=$(cv_suffix)
SKU="CVD-$SFX"
register_user dupcode $LINENO
create_product "$USER_TOKEN" "$(product_json "Original $SFX" "original" 10 "$SKU" 1)" $LINENO

# When
cv_step When "the user adds another product with the same product code" $LINENO
cv_http POST /products "$(product_json "Copy $SFX" "copy" 11 "$SKU" 2)" -H "Authorization: Bearer $USER_TOKEN"
DUP_STATUS=$CV_HTTP_STATUS; DUP_BODY=$CV_HTTP_BODY

# Then
cv_step Then "second request fails with a uniqueness error (409) and no duplicate exists" $LINENO
[ "$DUP_STATUS" = "409" ] || cv_fail "expected 409 for duplicate product code got $DUP_STATUS: $DUP_BODY" $LINENO
printf '%s' "$DUP_BODY" | jq -e '.error | type == "string" and length > 0' >/dev/null || cv_fail "expected error message got $DUP_BODY" $LINENO
cv_http GET /products "" 200
[ "$(count_sku "$SKU")" = "1" ] || cv_fail "expected exactly 1 product with code $SKU got $(count_sku "$SKU")" $LINENO

# Cleanup
cv_step Cleanup "products and users live only in app memory; the API has no delete route, nothing to remove" $LINENO
echo "no delete endpoint for products/users; data is in-memory and cleared on app restart"

echo "CODEVALID_TEST_ASSERTION_OK:add_product_duplicate_code_error"
