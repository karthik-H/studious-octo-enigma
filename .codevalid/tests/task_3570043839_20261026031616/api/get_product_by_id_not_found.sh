#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3570043839_20261026031616/api/_infra.sh

# Given
cv_step Given "a syntactically valid product id (UUID) that no product has" $LINENO
MISSING_ID=$(cat /proc/sys/kernel/random/uuid)
cv_http GET /products 200
n=$(printf '%s' "$CV_HTTP_BODY" | jq --arg i "$MISSING_ID" '[.products[] | select(.id == $i)] | length')
[ "$n" = "0" ] || cv_fail "expected generated id $MISSING_ID to be unused got $n matches" $LINENO

# When
cv_step When "an anonymous client requests GET /products/{missing id}" $LINENO
cv_http GET "/products/$MISSING_ID"

# Then
cv_step Then "404 with an error message and no internal details" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 got $CV_HTTP_STATUS" $LINENO
err=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty' 2>/dev/null || true)
[ -n "$err" ] || cv_fail "expected JSON .error message got $CV_HTTP_BODY" $LINENO
if printf '%s' "$CV_HTTP_BODY" | grep -Eqi 'stack|at [A-Za-z0-9_.]+ \(|/app/|node_modules|dist/'; then
  cv_fail "expected no internal details in error body got $CV_HTTP_BODY" $LINENO
fi

# Cleanup
cv_step Cleanup "nothing created; nothing to remove" $LINENO
cv_no_delete_note
echo "CODEVALID_TEST_ASSERTION_OK:get_product_by_id_not_found"
