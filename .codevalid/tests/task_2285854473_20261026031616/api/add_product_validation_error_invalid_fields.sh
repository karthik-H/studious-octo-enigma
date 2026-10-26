#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2285854473_20261026031616/api/_infra.sh

# Given
cv_step Given "signed-in user and a set of malformed product payloads" $LINENO
cv_prereq "register user" $LINENO
register_user invalid $LINENO
SFX=$(cv_suffix)
SKU_NONAME="CV-NONAME-$SFX"
SKU_NODESC="CV-NODESC-$SFX"
SKU_STRPRICE="CV-STRPRICE-$SFX"
SKU_NEGPRICE="CV-NEGPRICE-$SFX"
P_NONAME=$(jq -nc --arg s "$SKU_NONAME" '{description:"no name given",price:10,sku:$s,stock:1}')
P_NODESC=$(jq -nc --arg s "$SKU_NODESC" --arg n "Empty desc $SFX" '{name:$n,description:"",price:10,sku:$s,stock:1}')
P_STRPRICE=$(jq -nc --arg s "$SKU_STRPRICE" --arg n "Bad price $SFX" '{name:$n,description:"price is text",price:"abc",sku:$s,stock:1}')
P_NEGPRICE=$(jq -nc --arg s "$SKU_NEGPRICE" --arg n "Neg price $SFX" '{name:$n,description:"price below zero",price:-5,sku:$s,stock:1}')

# When
cv_step When "POST /products with each malformed payload" $LINENO
cv_http POST /products "$P_NONAME" -H "Authorization: Bearer $REG_TOKEN"
S_NONAME=$CV_HTTP_STATUS; B_NONAME=$CV_HTTP_BODY
cv_http POST /products "$P_NODESC" -H "Authorization: Bearer $REG_TOKEN"
S_NODESC=$CV_HTTP_STATUS; B_NODESC=$CV_HTTP_BODY
cv_http POST /products "$P_STRPRICE" -H "Authorization: Bearer $REG_TOKEN"
S_STRPRICE=$CV_HTTP_STATUS; B_STRPRICE=$CV_HTTP_BODY
cv_http POST /products "$P_NEGPRICE" -H "Authorization: Bearer $REG_TOKEN"
S_NEGPRICE=$CV_HTTP_STATUS; B_NEGPRICE=$CV_HTTP_BODY

# Then
cv_step Then "each request gets a 400 validation error and no product is created" $LINENO
check_rejected() {
  local label="$1" status="$2" body="$3" sku="$4" line="$5" err count
  count=$(db_count_sku "$sku")
  [ "$status" = "400" ] || cv_fail "expected 400 validation error for $label got $status: $body (rows created: $count)" "$line"
  err=$(printf '%s' "$body" | jq -r '.error // empty' 2>/dev/null || true)
  [ -n "$err" ] || cv_fail "expected error message for $label got $body" "$line"
  [ "$count" = "0" ] || cv_fail "expected no product created for $label got $count rows" "$line"
}
check_rejected "missing name" "$S_NONAME" "$B_NONAME" "$SKU_NONAME" $LINENO
check_rejected "non-numeric price" "$S_STRPRICE" "$B_STRPRICE" "$SKU_STRPRICE" $LINENO
check_rejected "negative price" "$S_NEGPRICE" "$B_NEGPRICE" "$SKU_NEGPRICE" $LINENO
check_rejected "empty description" "$S_NODESC" "$B_NODESC" "$SKU_NODESC" $LINENO

# Cleanup
cv_step Cleanup "remove any products and the user created by this test" $LINENO
for s in "$SKU_NONAME" "$SKU_NODESC" "$SKU_STRPRICE" "$SKU_NEGPRICE"; do db_cleanup_sku "$s"; done
db_cleanup_user "$USER_ID"

echo "CODEVALID_TEST_ASSERTION_OK:add_product_validation_error_invalid_fields"
