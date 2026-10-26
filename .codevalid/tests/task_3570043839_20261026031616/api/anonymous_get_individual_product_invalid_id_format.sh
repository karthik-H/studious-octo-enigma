#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3570043839_20261026031616/api/_infra.sh

# Given
cv_step Given "a real product exists so the catalog is reachable, and a malformed (non-UUID) id is prepared" $LINENO
register_user "badid" $LINENO
SELLER_ID=$USER_ID
SFX=$(cv_suffix)
create_product "$USER_TOKEN" "$(product_json "badid item $SFX" "invalid id test" 9.99 "badid-$SFX" 2)" $LINENO
BAD_ID="not-a-valid-id-$SFX"

# When
cv_step When "an anonymous user requests GET /products/{malformed id}" $LINENO
cv_http GET "/products/$BAD_ID"

# Then
cv_step Then "the API rejects the id with 400 Bad Request and an error message, not 404 or 5xx" $LINENO
[ "$CV_HTTP_STATUS" = "400" ] || cv_fail "expected 400 for malformed id got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty' 2>/dev/null || true)
[ -n "$ERR" ] || cv_fail "expected an .error message in body got $CV_HTTP_BODY" $LINENO
HAS_PRODUCT=$(printf '%s' "$CV_HTTP_BODY" | jq -r 'has("product")' 2>/dev/null || echo false)
[ "$HAS_PRODUCT" = "false" ] || cv_fail "expected no product in the error body got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "delete the seeded product and seller" $LINENO
cleanup_rows "$PRODUCT_ID" "$SELLER_ID"

echo "CODEVALID_TEST_ASSERTION_OK:anonymous_get_individual_product_invalid_id_format"
