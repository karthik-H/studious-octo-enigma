#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3570043839_20261026031616/api/_infra.sh

# Given
cv_step Given "three products exist in the catalog" $LINENO
seed_product "page-a" $LINENO
seed_product "page-b" $LINENO
seed_product "page-c" $LINENO
cv_http GET /products 200
total=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')
[ "$total" -ge 3 ] || cv_fail "expected at least 3 products in catalog got $total" $LINENO

# When
cv_step When "an anonymous client requests GET /products?page=1&pageSize=1" $LINENO
cv_http GET "/products?page=1&pageSize=1"

# Then
cv_step Then "200 with only one page (at most pageSize=1 products) of the catalog" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.products | type')" = "array" ] || cv_fail "expected .products array got $CV_HTTP_BODY" $LINENO
n=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')
[ "$n" -ge 1 ] || cv_fail "expected 1 product on page 1 got $n" $LINENO
[ "$n" -le 1 ] || cv_fail "expected at most 1 product with pageSize=1 got $n of $total (pagination params ignored)" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove through the API" $LINENO
cv_no_delete_note
echo "CODEVALID_TEST_ASSERTION_OK:anonymous_get_paginated_or_filtered_catalog"
