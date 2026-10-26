#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5703506414_20261026031616/api/_infra.sh

# Given
cv_step Given "A unique product payload and no signed-in session" $LINENO
SKU="SKU-UNAUTH-$(cv_suffix)"
BODY=$(product_json "Unauth product" 5 "$SKU" 1)

# When
cv_step When "POST /products is sent without and with a bogus bearer token" $LINENO
cv_http POST /products "$BODY"
S1=$CV_HTTP_STATUS
cv_http POST /products "$BODY" -H "Authorization: Bearer not.a.validtoken"
S2=$CV_HTTP_STATUS

# Then
cv_step Then "Both requests are rejected and the catalog is unchanged" $LINENO
case "$S1" in 401|403) ;; *) cv_fail "expected 401/403 without token got $S1" $LINENO ;; esac
case "$S2" in 401|403) ;; *) cv_fail "expected 401/403 with bogus token got $S2" $LINENO ;; esac
N=$(count_sku "$SKU")
[ "$N" = "0" ] || cv_fail "expected 0 products with sku $SKU got $N" $LINENO
# Cleanup
cv_step Cleanup "No delete API exists; test data lives only in the in-memory store and uses unique values" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_catalog_change_blocked"
