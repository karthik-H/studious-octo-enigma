#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3570043839_20261026031616/api/_infra.sh

# Given
cv_step Given "the catalog holds zero products (app restarted to clear in-memory data)" $LINENO
restart_app $LINENO
cv_prereq "confirm the catalog is empty before the anonymous request" $LINENO

# When
cv_step When "an anonymous client requests GET /products" $LINENO
cv_http GET /products

# Then
cv_step Then "200 with an empty products array and no auth required" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.products | type')" = "array" ] || cv_fail "expected .products array got $CV_HTTP_BODY" $LINENO
len=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')
[ "$len" = "0" ] || cv_fail "expected 0 products got $len" $LINENO

# Cleanup
cv_step Cleanup "nothing created; nothing to remove" $LINENO
cv_no_delete_note
echo "CODEVALID_TEST_ASSERTION_OK:anonymous_get_empty_product_catalog"
