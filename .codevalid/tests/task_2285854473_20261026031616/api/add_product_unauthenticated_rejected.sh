#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_2285854473_20261026031616/api/_infra.sh

# Given
cv_step Given "a valid product payload with unique codes and no session" $LINENO
SFX=$(cv_suffix)
SKU1="CVN1-$SFX"; SKU2="CVN2-$SFX"; SKU3="CVN3-$SFX"

# When
cv_step When "POST /products without a token, with a garbage token and with a forged-signature token" $LINENO
cv_http POST /products "$(product_json "Anon $SFX" "no auth" 3 "$SKU1" 1)"
S_NONE=$CV_HTTP_STATUS; B_NONE=$CV_HTTP_BODY
cv_http POST /products "$(product_json "Anon $SFX" "bad token" 3 "$SKU2" 1)" -H "Authorization: Bearer not-a-real-token"
S_BAD=$CV_HTTP_STATUS; B_BAD=$CV_HTTP_BODY
cv_http POST /products "$(product_json "Anon $SFX" "forged" 3 "$SKU3" 1)" -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.Zm9yZ2Vk"
S_FORGED=$CV_HTTP_STATUS

# Then
cv_step Then "each request is rejected with 401 and no product is added" $LINENO
[ "$S_NONE" = "401" ] || cv_fail "expected 401 without token got $S_NONE" $LINENO
printf '%s' "$B_NONE" | jq -e '.error | type == "string" and length > 0' >/dev/null || cv_fail "expected error message got $B_NONE" $LINENO
[ "$S_BAD" = "401" ] || cv_fail "expected 401 with invalid token got $S_BAD" $LINENO
printf '%s' "$B_BAD" | jq -e '.error | type == "string" and length > 0' >/dev/null || cv_fail "expected error message got $B_BAD" $LINENO
[ "$S_FORGED" = "401" ] || cv_fail "expected 401 with forged token got $S_FORGED" $LINENO
cv_http GET /products "" 200
for s in "$SKU1" "$SKU2" "$SKU3"; do
  [ "$(count_sku "$s")" = "0" ] || cv_fail "expected no product with sku $s in catalog got one" $LINENO
done

# Cleanup
cv_step Cleanup "nothing was created" $LINENO
echo "no data created"
echo "CODEVALID_TEST_ASSERTION_OK:add_product_unauthenticated_rejected"
