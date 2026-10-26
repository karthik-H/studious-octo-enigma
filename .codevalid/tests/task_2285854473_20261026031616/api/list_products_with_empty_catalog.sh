#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2285854473_20261026031616/api/_infra.sh

# Given
cv_step Given "fresh service with no products added and a signed-in user" $LINENO
cv_prereq "restart the app so the in-memory catalog starts empty" $LINENO
restart_app $LINENO
register_user listempty $LINENO

# When
cv_step When "signed-in user lists the catalog with GET /products" $LINENO
cv_http GET /products "" 200 -H "Authorization: Bearer $USER_TOKEN"

# Then
cv_step Then "response is 200 with an empty products array" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.products | type == "array"' >/dev/null || cv_fail "expected .products to be an array got $CV_HTTP_BODY" $LINENO
N=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')
[ "$N" = "0" ] || cv_fail "expected 0 products in an empty catalog got $N" $LINENO

# Cleanup
cv_step Cleanup "products and users live only in app memory; the API has no delete route, nothing to remove" $LINENO
echo "no delete endpoint for products/users; data is in-memory and cleared on app restart"

echo "CODEVALID_TEST_ASSERTION_OK:list_products_with_empty_catalog"
