#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_2285854473_20261026031616/api/_infra.sh

CAT="access"; SEV="serious"
TITLE="Product catalog readable without authentication despite requirement for signed-in users"

cv_step Given "a signed-in user adds a product carrying internal-looking metadata" $LINENO
SFX=$(cv_suffix)
SKU="CVSEC-$SFX"
EMAIL="secaccess.$SFX@example.com"
BODY=$(jq -nc --arg e "$EMAIL" '{email:$e,name:"sec access",password:"Passw0rd!secret"}')
cv_http POST /auth/register "$BODY"
[ "$CV_HTTP_STATUS" = "201" ] || { echo "setup failed: register returned $CV_HTTP_STATUS"; exit 1; }
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || { echo "setup failed: no token"; exit 1; }
cv_http POST /products "$(product_json "Sec item $SFX" "internal $SFX" 7 "$SKU" 11)" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || { echo "setup failed: create product returned $CV_HTTP_STATUS"; exit 1; }

cv_step When "anonymous GET /products and GET /products/ with no credentials" $LINENO
cv_http GET /products
S1=$CV_HTTP_STATUS; B1=$CV_HTTP_BODY
cv_http GET /products/
S2=$CV_HTTP_STATUS

cv_step Then "decide from status and exposed fields" $LINENO
if [ "$S1" = "200" ] && printf '%s' "$B1" | jq -e --arg s "$SKU" 'any(.products[]?; .sku == $s)' >/dev/null 2>&1; then
  FIELDS=$(printf '%s' "$B1" | jq -r --arg s "$SKU" '[.products[] | select(.sku == $s) | keys[]] | join(",")')
  printf 'CV_SECURITY|vulnerable|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" \
    "anonymous GET /products -> $S1 (GET /products/ -> $S2) returned full product records incl. fields $FIELDS (stock and createdAt)"
else
  printf 'CV_SECURITY|secure|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" \
    "anonymous GET /products -> $S1 and GET /products/ -> $S2 without exposing the seeded product"
fi
exit 0
