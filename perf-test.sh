#!/bin/bash
# perf-test.sh — Universal website performance tester
# Works on any site: static, WordPress, PHP, Next.js, etc.
#
# Usage:
#   ./perf-test.sh https://example.com
#   ./perf-test.sh https://example.com --requests 20 --concurrent 5
#   ./perf-test.sh https://example.com --json          # AI-readable JSON
#   ./perf-test.sh https://example.com --html           # shareable HTML report
#   ./perf-test.sh https://example.com --json --html    # both
#
# One-liner install & run:
#   curl -sL https://raw.githubusercontent.com/user/repo/main/perf-test.sh | bash -s -- https://example.com
#
# Requirements: curl, bash 4+
# Optional: jq (for pretty JSON)

set -euo pipefail

# ─── Defaults ───────────────────────────────────────────────────────────────

REQUESTS=10
CONCURRENT=3
PATHS=""
OUTPUT_JSON=false
OUTPUT_HTML=false
TIMEOUT=30
VERSION="1.0.0"

# ─── Colors ─────────────────────────────────────────────────────────────────

if [ -t 1 ]; then
  GREEN='\033[0;32m'  YELLOW='\033[1;33m'  RED='\033[0;31m'
  BLUE='\033[0;34m'   CYAN='\033[0;36m'    BOLD='\033[1m'
  DIM='\033[2m'       NC='\033[0m'
else
  GREEN='' YELLOW='' RED='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
fi

# ─── Parse args ─────────────────────────────────────────────────────────────

URL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --requests|-n)  REQUESTS="$2"; shift 2 ;;
    --concurrent|-c) CONCURRENT="$2"; shift 2 ;;
    --paths|-p)     PATHS="$2"; shift 2 ;;
    --json)         OUTPUT_JSON=true; shift ;;
    --html)         OUTPUT_HTML=true; shift ;;
    --timeout)      TIMEOUT="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 <url> [options]"
      echo ""
      echo "Options:"
      echo "  -n, --requests N     Requests per path (default: 10)"
      echo "  -c, --concurrent N   Concurrent requests (default: 3)"
      echo "  -p, --paths 'a,b,c'  Comma-separated paths (default: auto-discover)"
      echo "  --json               Output JSON (for AI/CI)"
      echo "  --html               Generate HTML report"
      echo "  --timeout N          Request timeout in seconds (default: 30)"
      echo "  -h, --help           Show this help"
      echo ""
      echo "Examples:"
      echo "  $0 https://example.com"
      echo "  $0 https://shop.byst.re -n 20 -c 5 --json --html"
      echo "  $0 https://myblog.com -p '/,/about,/contact'"
      exit 0
      ;;
    -*)             echo "Unknown option: $1"; exit 1 ;;
    *)              URL="$1"; shift ;;
  esac
done

if [ -z "$URL" ]; then
  echo "Usage: $0 <url> [--requests N] [--concurrent N] [--json] [--html]"
  exit 1
fi

# Normalize URL
URL="${URL%/}"
[[ "$URL" =~ ^https?:// ]] || URL="https://$URL"
BASE_HOST=$(echo "$URL" | sed -E 's|https?://([^/]+).*|\1|')

# ─── curl measurement ──────────────────────────────────────────────────────

CURL_FMT='%{time_namelookup}|%{time_connect}|%{time_appconnect}|%{time_starttransfer}|%{time_total}|%{size_download}|%{http_code}|%{num_redirects}|%{time_redirect}'

measure_url() {
  local url="$1"
  curl -s -o /dev/null -w "$CURL_FMT" -L --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "0|0|0|0|0|0|000|0|0"
}

ms() {
  # seconds → milliseconds (integer)
  python3 -c "print(int(float('${1:-0}') * 1000))" 2>/dev/null || echo "0"
}

# ─── Auto-discover paths ───────────────────────────────────────────────────

discover_paths() {
  local html
  html=$(curl -s -L --max-time 10 "$URL" 2>/dev/null) || return

  echo "$html" | grep -oE 'href="[^"#]+"' | sed 's/href="//;s/"$//' | while read -r href; do
    local path=""

    # Absolute URL on same host
    if [[ "$href" =~ ^https?://$BASE_HOST(/[^?]*) ]]; then
      path="${BASH_REMATCH[1]}"
    # Relative path
    elif [[ "$href" =~ ^/[^/] ]]; then
      path="${href%%\?*}"
    fi

    [ -z "$path" ] && continue
    [ "$path" = "/" ] && continue

    # Skip assets, APIs, framework internals
    echo "$path" | grep -qiE '\.(css|js|png|jpg|jpeg|gif|svg|ico|webp|woff2?|ttf|eot|xml|json|txt|map|webmanifest)$' && continue
    echo "$path" | grep -qE '^/(wp-content|wp-includes|wp-json|_next|static|assets|cdn-cgi|api|feed)' && continue
    echo "$path" | grep -q 'xmlrpc' && continue

    echo "$path"
  done | sort -u | head -5
}

# ─── Run load test for a single path ───────────────────────────────────────

# Temp dir for results
TMPDIR_PERF=$(mktemp -d)
trap "rm -rf '$TMPDIR_PERF'" EXIT

run_path_test() {
  local path="$1"
  local full_url
  [ "$path" = "/" ] && full_url="$URL" || full_url="${URL}${path}"

  local result_file="$TMPDIR_PERF/results_$(echo "$path" | tr '/' '_')"
  : > "$result_file"

  # Semaphore-based concurrency
  local pids=()
  local running=0

  for i in $(seq 1 "$REQUESTS"); do
    (
      local raw
      raw=$(measure_url "$full_url")
      echo "$raw" >> "$result_file"
    ) &
    pids+=($!)
    running=$((running + 1))

    if [ "$running" -ge "$CONCURRENT" ]; then
      wait "${pids[0]}" 2>/dev/null || true
      pids=("${pids[@]:1}")
      running=$((running - 1))
    fi
  done
  wait 2>/dev/null

  echo "$result_file"
}

# ─── Statistics helpers ─────────────────────────────────────────────────────

calc_stats() {
  local file="$1"
  local field="$2"  # 1-indexed field from curl output
  python3 -c "
import sys
vals = []
for line in open('$file'):
    parts = line.strip().split('|')
    if len(parts) >= $field:
        v = int(float(parts[$field - 1]) * 1000)
        vals.append(v)
if not vals:
    print('0|0|0|0|0')
    sys.exit()
vals.sort()
n = len(vals)
avg = sum(vals) // n
p50 = vals[n // 2]
p95 = vals[int(n * 0.95)]
mn = vals[0]
mx = vals[-1]
print(f'{avg}|{p50}|{p95}|{mn}|{mx}')
" 2>/dev/null || echo "0|0|0|0|0"
}

count_status() {
  local file="$1"
  local ok=0 err=0
  while IFS='|' read -r _ _ _ _ _ _ code _ _; do
    code=${code:-000}
    if [ "$code" -ge 200 ] 2>/dev/null && [ "$code" -lt 400 ] 2>/dev/null; then
      ok=$((ok + 1))
    else
      err=$((err + 1))
    fi
  done < "$file"
  echo "${ok}|${err}"
}

avg_size() {
  local file="$1"
  python3 -c "
vals = []
for line in open('$file'):
    parts = line.strip().split('|')
    if len(parts) >= 6:
        vals.append(float(parts[5]))
avg = sum(vals) / len(vals) if vals else 0
print(int(avg))
" 2>/dev/null || echo "0"
}

fmt_size() {
  local bytes="$1"
  if [ "$bytes" -lt 1024 ] 2>/dev/null; then
    echo "${bytes}B"
  elif [ "$bytes" -lt 1048576 ] 2>/dev/null; then
    python3 -c "print(f'{$bytes/1024:.1f}KB')" 2>/dev/null
  else
    python3 -c "print(f'{$bytes/1048576:.1f}MB')" 2>/dev/null
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}Performance Report: ${CYAN}${URL}${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─── Phase 1: Single request breakdown ──────────────────────────────────────

echo -e "${BOLD}Single Request Breakdown${NC} ${DIM}(homepage)${NC}"
echo ""

RAW=$(measure_url "$URL")
IFS='|' read -r r_dns r_conn r_tls r_ttfb r_total r_size r_code r_redir r_redir_time <<< "$RAW"

DNS=$(ms "$r_dns")
CONNECT=$(ms "$r_conn")
TLS=$(ms "$r_tls")
TTFB=$(ms "$r_ttfb")
TOTAL=$(ms "$r_total")
SIZE=$(printf "%.0f" "$r_size")
HTTP_CODE="$r_code"
REDIRECTS="$r_redir"
REDIR_TIME=$(ms "$r_redir_time")

color_metric() {
  local val="$1" good="$2" warn="$3"
  if [ "$val" -le "$good" ] 2>/dev/null; then echo -e "${GREEN}${val}ms${NC}"
  elif [ "$val" -le "$warn" ] 2>/dev/null; then echo -e "${YELLOW}${val}ms${NC}"
  else echo -e "${RED}${val}ms${NC}"
  fi
}

echo -e "  DNS:       $(color_metric "$DNS" 50 100)"
echo -e "  Connect:   $(color_metric "$CONNECT" 100 200)"
echo -e "  TLS:       $(color_metric "$TLS" 100 200)"
echo -e "  TTFB:      $(color_metric "$TTFB" 200 500)"
echo -e "  Total:     $(color_metric "$TOTAL" 500 1000)"
echo -e "  Size:      $(fmt_size "$SIZE")"
echo -e "  HTTP:      $HTTP_CODE"
[ "$REDIRECTS" -gt 0 ] 2>/dev/null && echo -e "  Redirects: $REDIRECTS (${REDIR_TIME}ms)"
echo ""

if [ "$HTTP_CODE" = "000" ]; then
  echo -e "${RED}Cannot connect to $URL${NC}"
  exit 1
fi

# ─── Phase 2: Discover or parse paths ───────────────────────────────────────

if [ -n "$PATHS" ]; then
  IFS=',' read -ra PATH_LIST <<< "$PATHS"
else
  echo -e "${DIM}Discovering pages...${NC}"
  DISCOVERED=()
  while IFS= read -r line; do
    [ -n "$line" ] && DISCOVERED+=("$line")
  done < <(discover_paths)
  if [ ${#DISCOVERED[@]} -gt 0 ]; then
    PATH_LIST=("/" "${DISCOVERED[@]}")
  else
    PATH_LIST=("/")
  fi

  if [ ${#DISCOVERED[@]} -gt 0 ]; then
    echo -e "  Found ${#DISCOVERED[@]} pages: ${DISCOVERED[*]}"
  else
    echo "  No internal links found, testing homepage only."
  fi
  echo ""
fi

# ─── Phase 3: Load test ────────────────────────────────────────────────────

TOTAL_PATHS=${#PATH_LIST[@]}
TOTAL_REQS=$((REQUESTS * TOTAL_PATHS))

echo -e "${BOLD}Load Test${NC} ${DIM}(${REQUESTS} req × ${TOTAL_PATHS} paths, concurrency ${CONCURRENT})${NC}"
echo ""

# Header
printf "  ${BOLD}%-28s %9s %9s %10s %7s %7s${NC}\n" "Path" "TTFB avg" "TTFB p95" "Total avg" "OK/Err" "Size"
printf "  %-28s %9s %9s %10s %7s %7s\n" "$(printf '─%.0s' $(seq 1 28))" "─────────" "─────────" "──────────" "───────" "───────"

# JSON accumulator
JSON_PATHS="["

START_TS=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || date +%s%3N)

for path in "${PATH_LIST[@]}"; do
  result_file=$(run_path_test "$path")

  # Extract stats
  ttfb_stats=$(calc_stats "$result_file" 4)  # time_starttransfer
  total_stats=$(calc_stats "$result_file" 5)  # time_total
  IFS='|' read -r ttfb_avg ttfb_p50 ttfb_p95 ttfb_min ttfb_max <<< "$ttfb_stats"
  IFS='|' read -r total_avg total_p50 total_p95 total_min total_max <<< "$total_stats"
  IFS='|' read -r ok err <<< "$(count_status "$result_file")"
  size=$(avg_size "$result_file")

  # Color TTFB
  if [ "$ttfb_avg" -le 200 ] 2>/dev/null; then ttfb_color="$GREEN"
  elif [ "$ttfb_avg" -le 500 ] 2>/dev/null; then ttfb_color="$YELLOW"
  else ttfb_color="$RED"
  fi

  # Truncate path for display
  display_path="$path"
  [ ${#display_path} -gt 28 ] && display_path="${display_path:0:25}..."

  printf "  %-28s ${ttfb_color}%8sms${NC} %8sms %9sms %3s/%-3s %7s\n" \
    "$display_path" "$ttfb_avg" "$ttfb_p95" "$total_avg" "$ok" "$err" "$(fmt_size "$size")"

  # JSON per path
  [ "$JSON_PATHS" != "[" ] && JSON_PATHS+=","
  JSON_PATHS+="{\"path\":\"$path\",\"ttfb\":{\"avg\":$ttfb_avg,\"p50\":$ttfb_p50,\"p95\":$ttfb_p95,\"min\":$ttfb_min,\"max\":$ttfb_max},\"total\":{\"avg\":$total_avg,\"p50\":$total_p50,\"p95\":$total_p95,\"min\":$total_min,\"max\":$total_max},\"ok\":$ok,\"errors\":$err,\"size_bytes\":$size}"
done

JSON_PATHS+="]"

END_TS=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || date +%s%3N)
TEST_DURATION=$((END_TS - START_TS))

# ─── Phase 4: Summary ──────────────────────────────────────────────────────

# Global TTFB stats — read directly from result files (no awk intermediary)
GLOBAL_STATS=$(python3 -c "
import glob
vals = []
for f in sorted(glob.glob('$TMPDIR_PERF/results_*')):
    for line in open(f):
        parts = line.strip().split('|')
        if len(parts) >= 4:
            try:
                v = int(float(parts[3]) * 1000)
                vals.append(v)
            except (ValueError, IndexError):
                pass
vals.sort()
n = len(vals)
if n == 0:
    print('0|0|0|0')
else:
    avg = sum(vals) // n
    p50 = vals[n // 2]
    p95 = vals[int(n * 0.95)]
    mx = vals[-1]
    print(f'{avg}|{p50}|{p95}|{mx}')
" 2>/dev/null || echo "0|0|0|0")

IFS='|' read -r g_ttfb_avg g_ttfb_p50 g_ttfb_p95 g_ttfb_max <<< "$GLOBAL_STATS"

# Count totals
TOTAL_OK=0
TOTAL_ERR=0
for f in "$TMPDIR_PERF"/results_*; do
  [ -f "$f" ] || continue
  IFS='|' read -r ok err <<< "$(count_status "$f")"
  TOTAL_OK=$((TOTAL_OK + ok))
  TOTAL_ERR=$((TOTAL_ERR + err))
done
TOTAL_DONE=$((TOTAL_OK + TOTAL_ERR))
SUCCESS_RATE=0
[ "$TOTAL_DONE" -gt 0 ] && SUCCESS_RATE=$((TOTAL_OK * 100 / TOTAL_DONE))

THROUGHPUT="0"
[ "$TEST_DURATION" -gt 0 ] && THROUGHPUT=$(python3 -c "print(f'{$TOTAL_DONE / ($TEST_DURATION / 1000):.1f}')" 2>/dev/null || echo "0")

echo ""
echo -e "${BOLD}Summary${NC}"
echo ""
echo "  Total requests:  $TOTAL_DONE"
echo -e "  Success rate:    $([ "$SUCCESS_RATE" -ge 95 ] && echo -e "${GREEN}${SUCCESS_RATE}%${NC}" || echo -e "${RED}${SUCCESS_RATE}%${NC}")"
echo -e "  Avg TTFB:        $(color_metric "$g_ttfb_avg" 200 500)"
echo -e "  P50 TTFB:        ${g_ttfb_p50}ms"
echo -e "  P95 TTFB:        $(color_metric "$g_ttfb_p95" 500 1000)"
echo "  Throughput:      ${THROUGHPUT} req/s"
echo "  Test duration:   $(python3 -c "print(f'{$TEST_DURATION / 1000:.1f}s')" 2>/dev/null)"
echo ""

# Verdict
if [ "$g_ttfb_avg" -le 200 ] 2>/dev/null; then
  VERDICT="Excellent"
  VERDICT_DETAIL="avg TTFB < 200ms"
  echo -e "  ${GREEN}${BOLD}Verdict: $VERDICT${NC} ${DIM}($VERDICT_DETAIL)${NC}"
elif [ "$g_ttfb_avg" -le 500 ] 2>/dev/null; then
  VERDICT="Good"
  VERDICT_DETAIL="avg TTFB < 500ms"
  echo -e "  ${GREEN}${BOLD}Verdict: $VERDICT${NC} ${DIM}($VERDICT_DETAIL)${NC}"
elif [ "$g_ttfb_avg" -le 1000 ] 2>/dev/null; then
  VERDICT="Needs improvement"
  VERDICT_DETAIL="avg TTFB 500-1000ms"
  echo -e "  ${YELLOW}${BOLD}Verdict: $VERDICT${NC} ${DIM}($VERDICT_DETAIL)${NC}"
else
  VERDICT="Poor"
  VERDICT_DETAIL="avg TTFB > 1s"
  echo -e "  ${RED}${BOLD}Verdict: $VERDICT${NC} ${DIM}($VERDICT_DETAIL)${NC}"
fi
echo ""

# ─── JSON output ────────────────────────────────────────────────────────────

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
JSON_FILE="perf-$(echo "$BASE_HOST" | tr '.' '-')-$(date +%Y%m%d-%H%M%S).json"

JSON_OUTPUT="{
  \"version\": \"$VERSION\",
  \"url\": \"$URL\",
  \"timestamp\": \"$TIMESTAMP\",
  \"config\": {
    \"requests_per_path\": $REQUESTS,
    \"concurrent\": $CONCURRENT,
    \"timeout\": $TIMEOUT
  },
  \"single_request\": {
    \"dns_ms\": $DNS,
    \"connect_ms\": $CONNECT,
    \"tls_ms\": $TLS,
    \"ttfb_ms\": $TTFB,
    \"total_ms\": $TOTAL,
    \"size_bytes\": $SIZE,
    \"http_code\": $HTTP_CODE,
    \"redirects\": $REDIRECTS,
    \"redirect_time_ms\": $REDIR_TIME
  },
  \"load_test\": {
    \"paths\": $JSON_PATHS,
    \"summary\": {
      \"total_requests\": $TOTAL_DONE,
      \"success_rate\": $SUCCESS_RATE,
      \"ttfb_avg_ms\": $g_ttfb_avg,
      \"ttfb_p50_ms\": $g_ttfb_p50,
      \"ttfb_p95_ms\": $g_ttfb_p95,
      \"ttfb_max_ms\": $g_ttfb_max,
      \"throughput_rps\": $THROUGHPUT,
      \"duration_ms\": $TEST_DURATION
    },
    \"verdict\": \"$VERDICT\",
    \"verdict_detail\": \"$VERDICT_DETAIL\"
  }
}"

if [ "$OUTPUT_JSON" = true ]; then
  echo "$JSON_OUTPUT" > "$JSON_FILE"
  if command -v jq &>/dev/null; then
    jq '.' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
  fi
  echo -e "${DIM}JSON saved: ${JSON_FILE}${NC}"
fi

# ─── HTML report ────────────────────────────────────────────────────────────

if [ "$OUTPUT_HTML" = true ]; then
  HTML_FILE="perf-$(echo "$BASE_HOST" | tr '.' '-')-$(date +%Y%m%d-%H%M%S).html"

  # Build paths table rows
  HTML_ROWS=""
  for path_json in $(echo "$JSON_PATHS" | python3 -c "
import json,sys
for p in json.loads(sys.stdin.read()):
    print(f\"{p['path']}|{p['ttfb']['avg']}|{p['ttfb']['p95']}|{p['total']['avg']}|{p['ok']}|{p['errors']}|{p['size_bytes']}\")
" 2>/dev/null); do
    IFS='|' read -r h_path h_ttfb_avg h_ttfb_p95 h_total_avg h_ok h_err h_size <<< "$path_json"
    h_size_fmt=$(fmt_size "$h_size")

    # TTFB color class
    ttfb_class="good"
    [ "$h_ttfb_avg" -gt 200 ] 2>/dev/null && ttfb_class="warn"
    [ "$h_ttfb_avg" -gt 500 ] 2>/dev/null && ttfb_class="bad"

    HTML_ROWS+="<tr><td class=\"path\">${h_path}</td><td class=\"${ttfb_class}\">${h_ttfb_avg}ms</td><td>${h_ttfb_p95}ms</td><td>${h_total_avg}ms</td><td>${h_ok}/${h_err}</td><td>${h_size_fmt}</td></tr>"
  done

  # Verdict class
  v_class="good"
  [ "$g_ttfb_avg" -gt 200 ] 2>/dev/null && v_class="warn"
  [ "$g_ttfb_avg" -gt 500 ] 2>/dev/null && v_class="bad"

  cat > "$HTML_FILE" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Perf Report — $BASE_HOST</title>
<style>
  :root { --bg: #0f172a; --card: #1e293b; --border: #334155; --text: #e2e8f0; --dim: #94a3b8; --good: #22c55e; --warn: #eab308; --bad: #ef4444; --accent: #3b82f6; }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; background: var(--bg); color: var(--text); padding: 2rem; max-width: 900px; margin: 0 auto; line-height: 1.6; }
  h1 { font-size: 1.5rem; margin-bottom: 0.25rem; }
  .url { color: var(--accent); font-size: 1.1rem; word-break: break-all; }
  .meta { color: var(--dim); font-size: 0.85rem; margin-bottom: 2rem; }
  .card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 1.5rem; margin-bottom: 1.5rem; }
  .card h2 { font-size: 1.1rem; margin-bottom: 1rem; color: var(--dim); font-weight: 500; }
  .breakdown { display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 1rem; }
  .metric { text-align: center; }
  .metric .value { font-size: 1.8rem; font-weight: 700; }
  .metric .label { font-size: 0.75rem; color: var(--dim); text-transform: uppercase; letter-spacing: 0.05em; }
  .good .value, td.good { color: var(--good); }
  .warn .value, td.warn { color: var(--warn); }
  .bad .value, td.bad { color: var(--bad); }
  table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
  th { text-align: left; color: var(--dim); font-weight: 500; padding: 0.5rem 0.75rem; border-bottom: 1px solid var(--border); font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.05em; }
  td { padding: 0.6rem 0.75rem; border-bottom: 1px solid var(--border); }
  .path { font-family: 'SF Mono', Monaco, monospace; font-size: 0.85rem; max-width: 250px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 1rem; text-align: center; }
  .verdict { font-size: 1.4rem; font-weight: 700; text-align: center; padding: 1rem; border-radius: 8px; }
  .verdict.good { background: rgba(34,197,94,0.1); color: var(--good); }
  .verdict.warn { background: rgba(234,179,8,0.1); color: var(--warn); }
  .verdict.bad { background: rgba(239,68,68,0.1); color: var(--bad); }
  .bar { height: 8px; border-radius: 4px; background: var(--border); margin-top: 0.5rem; overflow: hidden; }
  .bar-fill { height: 100%; border-radius: 4px; }
  .footer { text-align: center; color: var(--dim); font-size: 0.75rem; margin-top: 2rem; }
  .footer a { color: var(--accent); text-decoration: none; }
  @media (max-width: 600px) { body { padding: 1rem; } .breakdown { grid-template-columns: repeat(3, 1fr); } }
</style>
</head>
<body>
<h1>Performance Report</h1>
<p class="url">$URL</p>
<p class="meta">$TIMESTAMP &middot; $REQUESTS req/path &middot; concurrency $CONCURRENT</p>

<div class="card">
  <h2>Connection Breakdown</h2>
  <div class="breakdown">
    <div class="metric $([ "$DNS" -le 50 ] && echo good || ([ "$DNS" -le 100 ] && echo warn || echo bad))">
      <div class="value">${DNS}</div><div class="label">DNS (ms)</div>
    </div>
    <div class="metric $([ "$CONNECT" -le 100 ] && echo good || ([ "$CONNECT" -le 200 ] && echo warn || echo bad))">
      <div class="value">${CONNECT}</div><div class="label">Connect (ms)</div>
    </div>
    <div class="metric $([ "$TLS" -le 100 ] && echo good || ([ "$TLS" -le 200 ] && echo warn || echo bad))">
      <div class="value">${TLS}</div><div class="label">TLS (ms)</div>
    </div>
    <div class="metric $([ "$TTFB" -le 200 ] && echo good || ([ "$TTFB" -le 500 ] && echo warn || echo bad))">
      <div class="value">${TTFB}</div><div class="label">TTFB (ms)</div>
    </div>
    <div class="metric $([ "$TOTAL" -le 500 ] && echo good || ([ "$TOTAL" -le 1000 ] && echo warn || echo bad))">
      <div class="value">${TOTAL}</div><div class="label">Total (ms)</div>
    </div>
    <div class="metric">
      <div class="value">$(fmt_size "$SIZE")</div><div class="label">Size</div>
    </div>
  </div>
</div>

<div class="card">
  <h2>Load Test Results</h2>
  <table>
    <thead><tr><th>Path</th><th>TTFB avg</th><th>TTFB p95</th><th>Total avg</th><th>OK/Err</th><th>Size</th></tr></thead>
    <tbody>$HTML_ROWS</tbody>
  </table>
</div>

<div class="card">
  <h2>Summary</h2>
  <div class="summary">
    <div class="metric"><div class="value">${TOTAL_DONE}</div><div class="label">Requests</div></div>
    <div class="metric $([ "$SUCCESS_RATE" -ge 95 ] && echo good || echo bad)"><div class="value">${SUCCESS_RATE}%</div><div class="label">Success Rate</div></div>
    <div class="metric $([ "$g_ttfb_avg" -le 200 ] && echo good || ([ "$g_ttfb_avg" -le 500 ] && echo warn || echo bad))"><div class="value">${g_ttfb_avg}ms</div><div class="label">Avg TTFB</div></div>
    <div class="metric"><div class="value">${g_ttfb_p95}ms</div><div class="label">P95 TTFB</div></div>
    <div class="metric"><div class="value">${THROUGHPUT}</div><div class="label">req/s</div></div>
  </div>
</div>

<div class="verdict ${v_class}">${VERDICT} — ${VERDICT_DETAIL}</div>

<script>const data = $JSON_OUTPUT;</script>

<p class="footer">Generated by <a href="https://github.com/user/perf-test">perf-test.sh</a> v${VERSION}</p>
</body>
</html>
HTMLEOF

  echo -e "${DIM}HTML report: ${HTML_FILE}${NC}"
fi

# Always print JSON path hint
if [ "$OUTPUT_JSON" != true ] && [ "$OUTPUT_HTML" != true ]; then
  echo ""
  echo -e "${DIM}Tip: add --json for machine-readable output, --html for a shareable report${NC}"
fi
