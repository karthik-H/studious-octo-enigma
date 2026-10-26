#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3570043839_20261026031616/api/_infra.sh

# Given
cv_step Given "an id that is not a UUID (the format product ids use) and an existing product proving ids are UUIDs" $LINENO
seed_product "get_product_by_id_invalid_id_format" $LINENO
printf '%s' "$PRODUCT_ID" | grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' || cv_fail "expected product ids to be UUIDs got $PRODUCT_ID" $LINENO
BAD_ID="not-a-valid-id!$(cv_suffix)"

# When
cv_step When "an anonymous client requests GET /products/{malformed id}" $LINENO
cv_http GET "/products/$BAD_ID"

# Then
cv_step Then "400 bad-request validation error, not 404 not-found and not a 5xx" $LINENO
[ "$CV_HTTP_STATUS" = "400" ] || cv_fail "expected 400 for malformed id got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.error | type == "string" and length > 0' >/dev/null 2>&1 || cv_fail "expected JSON .error message got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove through the API" $LINENO
cv_no_delete_note
echo "CODEVALID_TEST_ASSERTION_OK:get_product_by_id_invalid_id_format"
