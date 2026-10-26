#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2285854473_20261026031616/api/_infra.sh

# Given
cv_step Given "a signed-in user adds a product and sees it in the catalog" $LINENO
SFX=$(cv_suffix)
SKU="CVE-$SFX"
PAYLOAD=$(product_json "Ephemeral $SFX" "kept in memory" 12.5 "$SKU" 2)
register_user ephemeral $LINENO
create_product "$USER_TOKEN" "$PAYLOAD" $LINENO
cv_http GET /products "" 200
[ "$(count_sku "$SKU")" = "1" ] || cv_fail "expected product $SKU visible before restart got $CV_HTTP_BODY" $LINENO

# When
cv_step When "service restarts, user signs in again and re-adds the same product" $LINENO
restart_app $LINENO
cv_http GET /products "" 200
AFTER_RESTART=$(count_sku "$SKU")
cv_prereq "users are in memory too: register again to get a valid session" $LINENO
register_user ephemeral2 $LINENO
cv_http POST /products "$PAYLOAD" -H "Authorization: Bearer $USER_TOKEN"
READD_STATUS=$CV_HTTP_STATUS; READD_BODY=$CV_HTTP_BODY

# Then
cv_step Then "product is gone after restart and re-adding it succeeds and is browseable" $LINENO
[ "$AFTER_RESTART" = "0" ] || cv_fail "expected product $SKU gone after restart got $AFTER_RESTART" $LINENO
[ "$READD_STATUS" = "201" ] || cv_fail "expected 201 re-adding product got $READD_STATUS: $READD_BODY" $LINENO
cv_http GET /products "" 200
[ "$(count_sku "$SKU")" = "1" ] || cv_fail "expected exactly 1 product $SKU after re-add got $(count_sku "$SKU")" $LINENO

# Cleanup
cv_step Cleanup "products and users live only in app memory; the API has no delete route, nothing to remove" $LINENO
echo "no delete endpoint for products/users; data is in-memory and cleared on app restart"

echo "CODEVALID_TEST_ASSERTION_OK:add_product_after_restart_ephemeral_catalog"
