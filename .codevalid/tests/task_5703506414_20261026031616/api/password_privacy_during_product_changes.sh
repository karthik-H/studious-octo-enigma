#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5703506414_20261026031616/api/_infra.sh

# Given
cv_step Given "A registered customer exists and its registration response hides the password" $LINENO
register_user privacy $LINENO
if body_mentions "$USER_PASSWORD" || body_mentions "passwordHash"; then cv_fail "expected register response without password got $CV_HTTP_BODY" $LINENO; fi
SKU="SKU-PRIV-$(cv_suffix)"

# When
cv_step When "The customer signs in, creates a product and reads the catalog" $LINENO
login_user "$USER_EMAIL" "$USER_PASSWORD" $LINENO
LOGIN_RESP=$CV_HTTP_BODY
cv_http POST /products "$(product_json "Privacy product" 9.5 "$SKU" 2)" -H "Authorization: Bearer $LOGIN_TOKEN"
POST_STATUS=$CV_HTTP_STATUS
POST_RESP=$CV_HTTP_BODY
cv_http GET /products 200
LIST_RESP=$CV_HTTP_BODY

# Then
cv_step Then "No response carries the password, its hash or a password field" $LINENO
[ "$POST_STATUS" = "201" ] || cv_fail "expected 201 from POST /products got $POST_STATUS" $LINENO
for R in "$LOGIN_RESP" "$POST_RESP" "$LIST_RESP"; do
  case "$R" in *"$USER_PASSWORD"*) cv_fail "expected response without plaintext password got $R" $LINENO ;; esac
  case "$R" in *assword*) cv_fail "expected response without any password field got $R" $LINENO ;; esac
done
TOKEN_PAYLOAD=$(printf "%s" "$LOGIN_TOKEN" | cut -d. -f2 | tr "_-" "/+")
while [ $(( ${#TOKEN_PAYLOAD} % 4 )) -ne 0 ]; do TOKEN_PAYLOAD="${TOKEN_PAYLOAD}="; done
DECODED=$(printf "%s" "$TOKEN_PAYLOAD" | base64 -d 2>/dev/null || true)
case "$DECODED" in *"$USER_PASSWORD"*|*assword*) cv_fail "expected token payload without password got $DECODED" $LINENO ;; esac
# Cleanup
cv_step Cleanup "No delete API exists; test data lives only in the in-memory store and uses unique values" $LINENO
echo "nothing to remove"

echo "CODEVALID_TEST_ASSERTION_OK:password_privacy_during_product_changes"
