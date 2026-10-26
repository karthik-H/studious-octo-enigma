#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3570043839_20261026031616/api/_infra.sh

# Given
cv_step Given "a seller has published three products so the catalog has more than one page of size 1" $LINENO
SFX=$(cv_suffix)
register_user "pager" $LINENO
SELLER_ID=$USER_ID
IDS=()
for i in 1 2 3; do
  cv_prereq "create product $i" $LINENO
  create_product "$USER_TOKEN" "$(product_json "page item $i $SFX" "paging test $SFX" "1$i.50" "page-$i-$SFX" 3)" $LINENO
  IDS+=("$PRODUCT_ID")
done
cv_http GET /products "" 200
TOTAL=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')
[ "$TOTAL" -ge 3 ] || cv_fail "expected the unpaginated catalog to hold at least 3 products got $TOTAL" $LINENO

# When
cv_step When "an anonymous user requests GET /products?page=1&pageSize=1" $LINENO
cv_http GET "/products?page=1&pageSize=1"

# Then
cv_step Then "the response is 200 with a products array holding only one page (at most 1 product)" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
IS_ARR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '(.products | type) == "array"')
[ "$IS_ARR" = "true" ] || cv_fail "expected .products to be an array got $CV_HTTP_BODY" $LINENO
PAGE_LEN=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')
[ "$PAGE_LEN" -le 1 ] || cv_fail "expected at most 1 product for pageSize=1 got $PAGE_LEN of $TOTAL (pagination params ignored)" $LINENO
[ "$PAGE_LEN" -lt "$TOTAL" ] || cv_fail "expected a subset of the $TOTAL-product catalog got $PAGE_LEN" $LINENO

# Cleanup
cv_step Cleanup "delete the seeded products and seller" $LINENO
cleanup_rows "${IDS[@]}" "$SELLER_ID"

echo "CODEVALID_TEST_ASSERTION_OK:anonymous_get_paginated_or_filtered_catalog"
