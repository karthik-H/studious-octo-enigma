#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5703506414_20261026031616/api/_infra.sh

# Given
cv_step Given "A forged token, a malformed header and an expired-looking token" $LINENO
SKU="SKU-NOLOGIN-$(cv_suffix)"
BODY=$(product_json "No login product" 1 "$SKU" 1)
H=$(printf "%s" "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64 | tr -d "=\n" | tr "/+" "_-")
P=$(printf "%s" "{\"sub\":\"x\",\"email\":\"x@example.com\",\"exp\":1}" | base64 | tr -d "=\n" | tr "/+" "_-")
FAKE="$H.$P.invalidsignatureinvalidsignatureinvalidsig"

# When
cv_step When "POST /products is sent with no auth, a non-bearer header and a forged token" $LINENO
cv_http POST /products "$BODY"
S1=$CV_HTTP_STATUS
cv_http POST /products "$BODY" -H "Authorization: Basic dXNlcjpwYXNz"
S2=$CV_HTTP_STATUS
cv_http POST /products "$BODY" -H "Authorization: Bearer $FAKE"
S3=$CV_HTTP_STATUS

# Then
cv_step Then "All are denied and nothing is added to the catalog" $LINENO
for S in "$S1" "$S2" "$S3"; do
  case "$S" in 401|403) ;; *) cv_fail "expected 401/403 without valid login got $S" $LINENO ;; esac
done
N=$(count_sku "$SKU")
[ "$N" = "0" ] || cv_fail "expected 0 products with sku $SKU got $N" $LINENO
# Cleanup
cv_step Cleanup "No delete API exists; test data lives only in the in-memory store and uses unique values" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:access_catalog_without_login"
