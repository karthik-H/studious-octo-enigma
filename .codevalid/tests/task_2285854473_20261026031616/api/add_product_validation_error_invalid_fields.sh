#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2285854473_20261026031616/api/_infra.sh

# Given
cv_step Given "a signed-in user and malformed product payloads" $LINENO
SFX=$(cv_suffix)
register_user validation $LINENO
P_NONAME=$(jq -nc --arg s "CVV1-$SFX" '{description:"no name",price:5,sku:$s,stock:1}')
P_EMPTYDESC=$(jq -nc --arg n "Empty desc $SFX" --arg s "CVV2-$SFX" '{name:$n,description:"",price:5,sku:$s,stock:1}')
P_TEXTPRICE=$(jq -nc --arg n "Text price $SFX" --arg s "CVV3-$SFX" '{name:$n,description:"text price",price:"abc",sku:$s,stock:1}')
P_NEGPRICE=$(jq -nc --arg n "Neg price $SFX" --arg s "CVV4-$SFX" '{name:$n,description:"negative",price:-1,sku:$s,stock:1}')

# When
cv_step When "POST /products with missing name, empty description, non-numeric and negative price" $LINENO
cv_http POST /products "$P_NONAME" -H "Authorization: Bearer $USER_TOKEN"; S1=$CV_HTTP_STATUS; B1=$CV_HTTP_BODY
cv_http POST /products "$P_EMPTYDESC" -H "Authorization: Bearer $USER_TOKEN"; S2=$CV_HTTP_STATUS; B2=$CV_HTTP_BODY
cv_http POST /products "$P_TEXTPRICE" -H "Authorization: Bearer $USER_TOKEN"; S3=$CV_HTTP_STATUS; B3=$CV_HTTP_BODY
cv_http POST /products "$P_NEGPRICE" -H "Authorization: Bearer $USER_TOKEN"; S4=$CV_HTTP_STATUS; B4=$CV_HTTP_BODY

# Then
cv_step Then "each request gets a 400 validation error and no product is created" $LINENO
[ "$S1" = "400" ] || cv_fail "expected 400 for missing name got $S1: $B1" $LINENO
[ "$S3" = "400" ] || cv_fail "expected 400 for non-numeric price got $S3: $B3" $LINENO
[ "$S4" = "400" ] || cv_fail "expected 400 for negative price got $S4: $B4" $LINENO
for b in "$B1" "$B3" "$B4"; do
  printf '%s' "$b" | jq -e '.error | type == "string" and length > 0' >/dev/null || cv_fail "expected validation error message got $b" $LINENO
done
cv_http GET /products "" 200
for s in "CVV1-$SFX" "CVV3-$SFX" "CVV4-$SFX"; do
  [ "$(count_sku "$s")" = "0" ] || cv_fail "expected no product with sku $s got one" $LINENO
done
[ "$S2" = "400" ] || cv_fail "expected 400 for empty description got $S2: $B2" $LINENO
[ "$(count_sku "CVV2-$SFX")" = "0" ] || cv_fail "expected no product created for empty description got one" $LINENO

# Cleanup
cv_step Cleanup "products and users live only in app memory; the API has no delete route, nothing to remove" $LINENO
echo "no delete endpoint for products/users; data is in-memory and cleared on app restart"

echo "CODEVALID_TEST_ASSERTION_OK:add_product_validation_error_invalid_fields"
