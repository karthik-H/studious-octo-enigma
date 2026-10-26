#!/usr/bin/env bash
# Shared helpers for this feature's API tests. Sourced first by every script.
export BASE_URL="${BASE_URL:-http://app:6713}"
export DATABASE_URL="${DATABASE_URL:-postgresql://app:app@toxiproxy:5432/appdb}"

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

# --- feature helpers (POST /auth/register; users live in PostgreSQL table "users") ---
export CV_APP_RESTART_URL="${CV_APP_RESTART_URL:-http://app:6714/}"
cv_suffix() { printf '%s%s' "$(date +%s%N)" "$RANDOM"; }
unique_email() { printf 'reg.%s.%s@example.com' "${1:-u}" "$(cv_suffix)"; }
register_body() { jq -nc --arg e "$1" --arg n "$2" --arg p "$3" '{email:$e,name:$n,password:$p}'; }
login_body() { jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}'; }
sql_lit() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"; }
# count users rows with the given (lower-cased) email
user_count_by_email() { psql -tAc "SELECT count(*) FROM users WHERE lower(email) = lower($(sql_lit "$1"))"; }
user_count_by_name() { psql -tAc "SELECT count(*) FROM users WHERE name = $(sql_lit "$1")"; }
delete_users_by_email() { local e; for e in "$@"; do [ -n "$e" ] && psql -qtAc "DELETE FROM users WHERE lower(email) = lower($(sql_lit "$e"))" >/dev/null || true; done; }
delete_users_by_name() { local n; for n in "$@"; do [ -n "$n" ] && psql -qtAc "DELETE FROM users WHERE name = $(sql_lit "$n")" >/dev/null || true; done; }
register_user() {
  USER_EMAIL=$(unique_email "${1:-u}")
  USER_PASSWORD="Str0ng!Pass$(cv_suffix)"
  cv_http POST /auth/register "$(register_body "$USER_EMAIL" "Test User" "$USER_PASSWORD")"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 from POST /auth/register got $CV_HTTP_STATUS" "${2:-}"
  USER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
  USER_TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
  [ -n "$USER_ID" ] || cv_fail "expected user.id in register response got $CV_HTTP_BODY" "${2:-}"
  export USER_EMAIL USER_PASSWORD USER_ID USER_TOKEN
}
# Restart the app process via the entrypoint's restart control. Detects the restart by the
# app's PostgreSQL pool connections (pg_stat_activity pids) being replaced, then waits for HTTP.
_app_backend_pids() {
  psql -tAc "SELECT coalesce(string_agg(pid::text, ' ' ORDER BY pid), '') FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid() AND backend_type = 'client backend'"
}
restart_app() {
  local before ctl i p alive code
  command curl -s -o /dev/null "$BASE_URL/products" || true
  before=$(_app_backend_pids)
  [ -n "$before" ] || cv_fail "expected app pool connections in pg_stat_activity before restart got none" "${1:-}"
  echo "app backend pids before restart: $before"
  ctl=$(command curl -sS -m 5 "$CV_APP_RESTART_URL" 2>&1) || cv_fail "expected restart control at $CV_APP_RESTART_URL to answer got: $ctl" "${1:-}"
  echo "restart control replied: $ctl"
  for i in $(seq 1 60); do
    alive=0
    for p in $before; do
      [ "$(psql -tAc "SELECT count(*) FROM pg_stat_activity WHERE pid = $p")" = "0" ] || alive=1
    done
    if [ "$alive" = 0 ]; then
      code=$(command curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/" || echo 000)
      if [ "$code" = "200" ]; then echo "app restarted (old pool connections gone, / -> 200 after ${i} polls)"; return 0; fi
    fi
    sleep 0.5
  done
  cv_fail "expected app process to restart (old pool connections dropped and / -> 200) but it did not" "${1:-}"
}
