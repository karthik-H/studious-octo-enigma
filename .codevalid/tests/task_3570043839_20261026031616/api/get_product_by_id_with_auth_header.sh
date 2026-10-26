#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3570043839_20261026031616/api/_infra.sh

# Given
cv_step Given "an existing product and a signed-in user's bearer token" $LINENO
seed_product "withauth" $LINENO
register_user "browser" $LINENO
cv_prereq "capture the anonymous response for comparison" $LINENO
cv_http GET "/products/$PRODUCT_ID" 200
ANON_BODY=$(printf '%s' "$CV_HTTP_BODY" | jq -S -c '.')

# When
cv_step When "the client requests GET /products/{id} with an Authorization: Bearer header" $LINENO
cv_http GET "/products/$PRODUCT_ID" -H "Authorization: Bearer $USER_TOKEN"

# Then
cv_step Then "200 with exactly the same product payload as the anonymous request" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
AUTH_BODY=$(printf '%s' "$CV_HTTP_BODY" | jq -S -c '.')
[ "$AUTH_BODY" = "$ANON_BODY" ] || cv_fail "expected same body as anonymous ($ANON_BODY) got $AUTH_BODY" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id')" = "$PRODUCT_ID" ] || cv_fail "expected product.id $PRODUCT_ID" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.sku')" = "$SEED_SKU" ] || cv_fail "expected product.sku $SEED_SKU" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove through the API" $LINENO
cv_no_delete_note
echo "CODEVALID_TEST_ASSERTION_OK:get_product_by_id_with_auth_header"
