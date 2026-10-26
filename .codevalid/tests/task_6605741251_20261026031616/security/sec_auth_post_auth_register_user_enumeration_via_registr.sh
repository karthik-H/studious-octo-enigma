#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_6605741251_20261026031616/api/_infra.sh

cv_step Given "Probe registration responses for new vs already registered emails" $LINENO
EMAIL="enum.$(cv_suffix)@example.com"
PW="Enum!Pass$(cv_suffix)"

cv_http POST /auth/register "$(register_body "$EMAIL" "Enum Probe" "$PW")"
S_NEW=$CV_HTTP_STATUS
B_NEW=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // "ok"' 2>/dev/null)
if [ "$S_NEW" = "000" ]; then echo "app unreachable"; exit 1; fi

cv_http POST /auth/register "$(register_body "$EMAIL" "Enum Probe" "Other!Pass$(cv_suffix)")"
S_DUP=$CV_HTTP_STATUS
B_DUP=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // "ok"' 2>/dev/null | tr -d '|')

cv_step Then "Compare responses" $LINENO
echo "cleanup: no delete API, account is in-memory only"
T="User enumeration via registration email uniqueness check"
if [ "$S_NEW" != "$S_DUP" ] || [ "$B_NEW" != "$B_DUP" ]; then
  printf 'CV_SECURITY|vulnerable|auth|warning|%s|new email -> %s, registered email -> %s (%s)\n' "$T" "$S_NEW" "$S_DUP" "$B_DUP"
else
  printf 'CV_SECURITY|secure|auth|warning|%s|new and registered email both -> %s with same body\n' "$T" "$S_NEW"
fi
exit 0
