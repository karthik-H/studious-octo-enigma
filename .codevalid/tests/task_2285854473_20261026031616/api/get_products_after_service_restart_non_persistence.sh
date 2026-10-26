#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2285854473_20261026031616/api/_infra.sh

# Given
cv_step Given "signed-in user adds products and sees them in GET /products" $LINENO
SFX=$(cv_suffix)
SKU_A="CVRA-$SFX"; SKU_B="CVRB-$SFX"
register_user restartget $LINENO
create_product "$USER_TOKEN" "$(product_json "Restart A $SFX" "before restart" 5 "$SKU_A" 1)" $LINENO
create_product "$USER_TOKEN" "$(product_json "Restart B $SFX" "before restart" 6 "$SKU_B" 1)" $LINENO
cv_http GET /products "" 200
[ "$(count_sku "$SKU_A")" = "1" ] && [ "$(count_sku "$SKU_B")" = "1" ] || cv_fail "expected both products visible before restart got $CV_HTTP_BODY" $LINENO

# When
cv_step When "the service is restarted and GET /products is called again" $LINENO
restart_app $LINENO
cv_http GET /products "" 200

# Then
cv_step Then "previously added products are no longer present" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.products | type == "array"' >/dev/null || cv_fail "expected .products array got $CV_HTTP_BODY" $LINENO
[ "$(count_sku "$SKU_A")" = "0" ] || cv_fail "expected product $SKU_A gone after restart got present" $LINENO
[ "$(count_sku "$SKU_B")" = "0" ] || cv_fail "expected product $SKU_B gone after restart got present" $LINENO

# Cleanup
cv_step Cleanup "products and users live only in app memory; the API has no delete route, nothing to remove" $LINENO
echo "no delete endpoint for products/users; data is in-memory and cleared on app restart"

echo "CODEVALID_TEST_ASSERTION_OK:get_products_after_service_restart_non_persistence"
