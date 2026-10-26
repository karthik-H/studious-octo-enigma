#!/usr/bin/env bash
# Shared helpers for this feature's API tests. Sourced first by every script.
export BASE_URL="${BASE_URL:-http://app:6713}"

# --- CodeValid diagnosis markers (parsed by the test runner; do not edit) ---
# cv_step  <Given|When|Then|Cleanup> "<what this section does>" $LINENO
# cv_prereq "<setup being done>" $LINENO
# cv_http  <METHOD> <url|/path> [json-body] [expected-status] [extra curl args, e.g. -H "Authorization: Bearer $T"]
#          performs the request (relative paths go to $BASE_URL), prints REQUEST_*/RESPONSE_*
#          and CV_HTTP|METHOD|url|status|ms, sets CV_HTTP_STATUS CV_HTTP_BODY CV_HTTP_MS
#          CV_HTTP_BODY_FILE CV_HTTP_HEADERS_FILE. Call it directly, never inside $(...).
#          A 3-digit expected-status (with or without a body) is asserted: a different status
#          fails the test via cv_fail. Omit it to assert on $CV_HTTP_STATUS yourself.
# cv_http  <METHOD> <url> <http_status>          (legacy: marker only, right after your own curl)
# cv_fail  "<expected X got Y>" $LINENO           (prints marker, exits 1)
cv_step() { printf 'CV_STEP|%s|%s|line=%s\n' "${1:-}" "${2:-}" "${3:-}"; }
cv_prereq() { printf 'CV_PREREQ|%s|line=%s\n' "${1:-}" "${2:-}"; }
cv_fail() { printf 'CV_ASSERT_FAIL|%s|line=%s\n' "${1:-}" "${2:-}"; exit 1; }
_cv_is_int() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
_cv_now_ms() {
  _cv_n=${EPOCHREALTIME:-}
  if [ -n "$_cv_n" ]; then _cv_secs_to_ms "$_cv_n"; return 0; fi
  _cv_n=$(date +%s%3N 2>/dev/null || true)
  _cv_is_int "$_cv_n" || _cv_n=$(( $(date +%s) * 1000 ))
  printf '%s' "$_cv_n"
}
_cv_ms_file() { printf '%s/.cv_last_ms.%s' "${TMPDIR:-/tmp}" "$$"; }
curl() {
  _cv_t0=$(_cv_now_ms)
  _cv_rc=0
  command curl "$@" || _cv_rc=$?
  _cv_t1=$(_cv_now_ms)
  printf '%s' "$((_cv_t1 - _cv_t0))" > "$(_cv_ms_file)" 2>/dev/null || :
  return $_cv_rc
}
# psql without a connection falls back to a local socket seed-test does not have; when
# DATABASE_URL is set and the call names no connection, connect through it.
psql() {
  if [ -n "${DATABASE_URL:-}" ]; then
    case " $* " in
      *" $DATABASE_URL "*|*" -h "*|*" --host"*|*" -d "*|*" --dbname"*|*"postgres://"*|*"postgresql://"*) ;;
      *) command psql "$DATABASE_URL" "$@"; return $? ;;
    esac
  fi
  command psql "$@"
}
_cv_secs_to_ms() {
  _cv_t=$(printf '%s' "${1:-0}" | tr ',' '.')
  _cv_s=${_cv_t%%.*}
  case "$_cv_t" in *.*) _cv_f=${_cv_t#*.}000 ;; *) _cv_f=000 ;; esac
  _cv_f=${_cv_f%"${_cv_f#???}"}
  while [ "${_cv_f#0}" != "$_cv_f" ]; do _cv_f=${_cv_f#0}; done
  _cv_is_int "$_cv_s" || _cv_s=0
  _cv_is_int "$_cv_f" || _cv_f=0
  printf '%s' "$(( _cv_s * 1000 + _cv_f ))"
}
_cv_is_status() { _cv_is_int "${1:-}" && [ ${#1} -eq 3 ]; }
cv_http() {
  if [ $# -ge 3 ] && [ $# -le 4 ] && _cv_is_status "$3" && { [ $# -eq 3 ] || _cv_is_int "$4"; }      && { [ -n "${4:-}" ] || [ -f "$(_cv_ms_file)" ]; }; then
    _cv_ms=${4:-}
    if [ -z "$_cv_ms" ] && [ -f "$(_cv_ms_file)" ]; then
      _cv_ms=$(cat "$(_cv_ms_file)" 2>/dev/null || true)
      rm -f "$(_cv_ms_file)" 2>/dev/null || :
    fi
    _cv_is_int "$_cv_ms" || _cv_ms=''
    printf 'CV_HTTP|%s|%s|%s%s\n' "$1" "$2" "$3" "${_cv_ms:+|$_cv_ms}"
    return 0
  fi
  _cv_method=${1:-GET}
  _cv_url=${2:-/}
  _cv_data=''
  _cv_expect=''
  if [ $# -ge 2 ]; then shift 2; else shift $#; fi
  if [ $# -ge 1 ] && ! _cv_is_status "$1"; then
    case "$1" in -*) ;; *) _cv_data=$1; shift ;; esac
  fi
  if [ $# -ge 1 ] && _cv_is_status "$1"; then _cv_expect=$1; shift; fi
  case "$_cv_url" in /*) _cv_url="${BASE_URL:-http://app:6713}$_cv_url" ;; esac
  CV_HTTP_BODY_FILE="${TMPDIR:-/tmp}/cv_http_body.$$"
  CV_HTTP_HEADERS_FILE="${TMPDIR:-/tmp}/cv_http_headers.$$"
  : > "$CV_HTTP_BODY_FILE"; : > "$CV_HTTP_HEADERS_FILE"
  printf 'REQUEST_HEADERS:\n%s %s\n' "$_cv_method" "$_cv_url"
  printf 'REQUEST_BODY:\n%s\n' "$_cv_data"
  if [ -n "$_cv_data" ]; then
    _cv_w=$(command curl -sS -X "$_cv_method" -H 'Content-Type: application/json' --data "$_cv_data" \
      -D "$CV_HTTP_HEADERS_FILE" -o "$CV_HTTP_BODY_FILE" -w '%{http_code} %{time_total}' "$@" "$_cv_url") || true
  else
    _cv_w=$(command curl -sS -X "$_cv_method" \
      -D "$CV_HTTP_HEADERS_FILE" -o "$CV_HTTP_BODY_FILE" -w '%{http_code} %{time_total}' "$@" "$_cv_url") || true
  fi
  CV_HTTP_STATUS=${_cv_w%% *}
  _cv_is_int "$CV_HTTP_STATUS" || CV_HTTP_STATUS=000
  case "$_cv_w" in *' '*) CV_HTTP_MS=$(_cv_secs_to_ms "${_cv_w#* }") ;; *) CV_HTTP_MS=0 ;; esac
  CV_HTTP_BODY=$(cat "$CV_HTTP_BODY_FILE" 2>/dev/null || true)
  printf 'RESPONSE_HEADERS:\n'; cat "$CV_HTTP_HEADERS_FILE" 2>/dev/null || true
  printf 'RESPONSE_BODY:\n%s\n' "$CV_HTTP_BODY"
  rm -f "$(_cv_ms_file)" 2>/dev/null || :
  printf 'CV_HTTP|%s|%s|%s|%s\n' "$_cv_method" "$_cv_url" "$CV_HTTP_STATUS" "$CV_HTTP_MS"
  if [ -n "$_cv_expect" ] && [ "$CV_HTTP_STATUS" != "$_cv_expect" ]; then
    cv_fail "expected HTTP $_cv_expect from $_cv_method $_cv_url got $CV_HTTP_STATUS: $(printf '%s' "$CV_HTTP_BODY" | head -c 300)" ""
  fi
  return 0
}
# --- end CodeValid diagnosis markers ---

# --- feature helpers (task_5703506414_20261026031616) ---
# Restart control endpoint served by .codevalid/entrypoint.sh inside the app container.
export CV_APP_RESTART_URL="${CV_APP_RESTART_URL:-http://app:6714/}"

app_url() { printf '%s%s' "$BASE_URL" "${1:-}"; }
cv_suffix() { printf '%s%s' "$(date +%s%N)" "$RANDOM"; }

# register_user <prefix> [line] : POST /auth/register; sets USER_EMAIL USER_PASSWORD USER_ID REG_TOKEN.
register_user() {
  local prefix="${1:-cvuser}"
  USER_EMAIL="${prefix}.$(cv_suffix)@example.com"
  USER_PASSWORD="Passw0rd!$(cv_suffix)"
  local body
  body=$(jq -nc --arg e "$USER_EMAIL" --arg n "CV $prefix" --arg p "$USER_PASSWORD" '{email:$e,name:$n,password:$p}')
  cv_http POST /auth/register "$body"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 from POST /auth/register got $CV_HTTP_STATUS" "${2:-}"
  USER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
  REG_TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
  [ -n "$USER_ID" ] && [ -n "$REG_TOKEN" ] || cv_fail "expected user.id and token in register response got $CV_HTTP_BODY" "${2:-}"
  export USER_EMAIL USER_PASSWORD USER_ID REG_TOKEN
}

# login_body <email> <password>
login_body() { jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}'; }

# login_user <email> <password> [line] : POST /auth/login expecting 200; sets LOGIN_TOKEN.
login_user() {
  cv_http POST /auth/login "$(login_body "$1" "$2")"
  [ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from POST /auth/login got $CV_HTTP_STATUS: $CV_HTTP_BODY" "${3:-}"
  LOGIN_TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
  [ -n "$LOGIN_TOKEN" ] || cv_fail "expected token in login response got $CV_HTTP_BODY" "${3:-}"
  export LOGIN_TOKEN
}

# product_json <name> <price> <sku> [stock]
product_json() {
  jq -nc --arg n "$1" --argjson p "$2" --arg s "$3" --argjson st "${4:-5}" \
    '{name:$n,description:"CodeValid test product",price:$p,sku:$s,stock:$st}'
}

# count_sku <sku> : products in GET /products carrying that sku (performs the GET).
count_sku() {
  cv_http GET /products
  [ "$CV_HTTP_STATUS" = "200" ] || { echo "-1"; return 0; }
  printf '%s' "$CV_HTTP_BODY" | jq --arg s "$1" '[.products[]? | select(.sku == $s)] | length'
}

# body_mentions <text> : true when the last response body or headers contain the text.
body_mentions() {
  grep -qF -- "$1" "$CV_HTTP_BODY_FILE" 2>/dev/null && return 0
  grep -qF -- "$1" "$CV_HTTP_HEADERS_FILE" 2>/dev/null && return 0
  return 1
}

# restart_app [line] : restarts the app process (in-memory state cleared), waits until it serves again.
restart_app() {
  local se sp body i code ctl
  se="restart.$(cv_suffix)@example.com"; sp="Sentinel!$(cv_suffix)"
  body=$(jq -nc --arg e "$se" --arg p "$sp" '{email:$e,name:"restart sentinel",password:$p}')
  cv_http POST /auth/register "$body"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering restart sentinel got $CV_HTTP_STATUS" "${1:-}"
  echo "requesting app restart via $CV_APP_RESTART_URL"
  ctl=$(command curl -sS -m 5 "$CV_APP_RESTART_URL" 2>&1) || cv_fail "expected restart control at $CV_APP_RESTART_URL to answer got: $ctl" "${1:-}"
  body=$(login_body "$se" "$sp")
  code=000
  for i in $(seq 1 60); do
    code=$(command curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
      --data "$body" "$BASE_URL/auth/login") || code=000
    if [ "$code" = "401" ]; then echo "app restarted (sentinel login -> 401 after ${i} polls)"; return 0; fi
    sleep 0.5
  done
  cv_fail "expected app to restart (sentinel login 401) but last status was $code" "${1:-}"
}
