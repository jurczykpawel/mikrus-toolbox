#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/server-exec.sh"

# Monitorowanie zużycia zasobów przez Sellf
# Użycie: ./local/monitor-sellf.sh <ssh_alias> [czas_w_sekundach] [app_name]
#
# Przykłady:
#   ./local/monitor-sellf.sh mikrus                    # 60 sekund, sellf-admin
#   ./local/monitor-sellf.sh mikrus 300                # 5 minut
#   ./local/monitor-sellf.sh mikrus 300 sellf-shop  # konkretna instancja

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ] || [ -z "${1:-}" ]; then
  echo "Użycie: $0 <ssh_alias> [czas_w_sekundach] [app_name]"
  echo ""
  echo "Przykłady:"
  echo "  $0 mikrus                    # 60 sekund, auto-detekcja"
  echo "  $0 mikrus 300                # 5 minut"
  echo "  $0 mikrus 300 sellf-shop  # konkretna instancja"
  exit 0
fi

SSH_ALIAS=${1}
DURATION=${2:-60}
APP_NAME=${3:-""}
INTERVAL=1

if [ -z "$APP_NAME" ]; then
  echo "🔍 Wykrywam instancje Sellf na serwerze..."
  INSTANCES=$(server_exec "pm2 list | grep sellf | awk '{print \$2}'")

  if [ -z "$INSTANCES" ]; then
    echo "❌ Nie znaleziono instancji Sellf"
    exit 1
  fi

  # Jeśli jest tylko jedna instancja - użyj jej
  COUNT=$(echo "$INSTANCES" | wc -l | xargs)
  if [ "$COUNT" -eq 1 ]; then
    APP_NAME="$INSTANCES"
    echo "✅ Znaleziono: $APP_NAME"
  else
    echo "Znalezione instancje:"
    echo "$INSTANCES" | nl
    echo ""
    read -p "Wybierz numer (1-$COUNT): " choice
    APP_NAME=$(echo "$INSTANCES" | sed -n "${choice}p")
  fi
fi

OUTPUT_FILE="sellf-metrics-$(date +%Y%m%d-%H%M%S).csv"

echo "📊 Monitorowanie: $APP_NAME"
echo "⏱️  Czas: ${DURATION}s (odświeżanie co ${INTERVAL}s)"
echo "💾 Zapis do: $OUTPUT_FILE"
echo ""
echo "timestamp,cpu_percent,memory_mb,memory_percent,uptime_min,restarts,status" > "$OUTPUT_FILE"

# Funkcja do pobrania metryk (kompatybilne z macOS i Linux)
get_metrics() {
  server_exec "pm2 jlist 2>/dev/null | python3 -c \"
import sys, json
try:
  data = json.load(sys.stdin)
  for proc in data:
    if proc.get('name') == '$APP_NAME':
      print(json.dumps(proc))
      break
except:
  pass
\""
}

# Początkowy snapshot
echo "📸 Snapshot początkowy:"
INITIAL=$(get_metrics)

if [ -z "$INITIAL" ] || [ "$INITIAL" = "null" ]; then
  echo "❌ Nie można pobrać metryk dla: $APP_NAME"
  echo "   Sprawdź czy PM2 działa: ssh $SSH_ALIAS 'pm2 list'"
  exit 1
fi

INITIAL_CPU=$(echo "$INITIAL" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('monit', {}).get('cpu', 0))")
INITIAL_MEM=$(echo "$INITIAL" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('monit', {}).get('memory', 0))")
INITIAL_MEM_MB=$((INITIAL_MEM / 1024 / 1024))
echo "   CPU: ${INITIAL_CPU}%"
echo "   RAM: ${INITIAL_MEM_MB} MB"
echo ""

# Loop monitorowania
END_TIME=$(($(date +%s) + DURATION))
MAX_CPU=0
MAX_MEM=0
AVG_CPU_TOTAL=0
AVG_MEM_TOTAL=0
SAMPLES=0

while [ "$(date +%s)" -lt "$END_TIME" ]; do
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  METRICS=$(get_metrics)

  if [ -z "$METRICS" ] || [ "$METRICS" = "null" ]; then
    echo "⚠️  Błąd pobierania metryk, pomijam próbkę..."
    sleep "$INTERVAL"
    continue
  fi

  # Parsuj JSON przez Python
  CPU=$(echo "$METRICS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('monit', {}).get('cpu', 0))")
  MEMORY=$(echo "$METRICS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('monit', {}).get('memory', 0))")
  MEMORY_MB=$((MEMORY / 1024 / 1024))
  UPTIME_MS=$(echo "$METRICS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('pm2_env', {}).get('pm_uptime', 0))")
  UPTIME_MIN=$((UPTIME_MS / 1000 / 60))
  RESTARTS=$(echo "$METRICS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('pm2_env', {}).get('restart_time', 0))")
  STATUS=$(echo "$METRICS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('pm2_env', {}).get('status', 'unknown'))")

  # Oblicz procent pamięci (zakładamy ~1GB RAM dostępne dla app)
  MEMORY_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($MEMORY_MB / 1024) * 100}")

  # Zapisz do CSV
  echo "$TIMESTAMP,$CPU,$MEMORY_MB,$MEMORY_PERCENT,$UPTIME_MIN,$RESTARTS,$STATUS" >> "$OUTPUT_FILE"

  # Aktualizuj statystyki
  MAX_CPU=$(python3 -c "print(max($MAX_CPU, $CPU))")
  if [ "$MEMORY_MB" -gt "$MAX_MEM" ]; then MAX_MEM=$MEMORY_MB; fi

  AVG_CPU_TOTAL=$(python3 -c "print($AVG_CPU_TOTAL + $CPU)")
  AVG_MEM_TOTAL=$((AVG_MEM_TOTAL + MEMORY_MB))
  SAMPLES=$((SAMPLES + 1))

  # Progress bar
  ELAPSED=$(($(date +%s) - (END_TIME - DURATION)))
  PROGRESS=$((ELAPSED * 100 / DURATION))
  printf "\r⏳ [%-50s] %d%% | CPU: %4.1f%% | RAM: %4d MB | Uptime: %dm" \
    "$(printf '#%.0s' $(seq 1 $((PROGRESS / 2))))" \
    "$PROGRESS" "$CPU" "$MEMORY_MB" "$UPTIME_MIN"

  sleep "$INTERVAL"
done

# Oblicz średnie
if [ "$SAMPLES" -gt 0 ]; then
  AVG_CPU=$(python3 -c "print(round($AVG_CPU_TOTAL / $SAMPLES, 1))")
  AVG_MEM=$((AVG_MEM_TOTAL / SAMPLES))
else
  AVG_CPU=0
  AVG_MEM=0
fi

echo ""
echo ""
echo "📈 Podsumowanie ($SAMPLES próbek):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CPU:"
echo "  Max:     ${MAX_CPU}%"
echo "  Średnia: ${AVG_CPU}%"
echo ""
echo "RAM:"
echo "  Max:     ${MAX_MEM} MB"
echo "  Średnia: ${AVG_MEM} MB"
echo ""

# Analiza dla Mikrus 3.0 (1GB RAM)
if [ "$MAX_MEM" -lt 500 ]; then
  echo "✅ Zużycie RAM: Świetne! Aplikacja zmieści się na Mikrus 3.0"
elif [ "$MAX_MEM" -lt 700 ]; then
  echo "⚠️  Zużycie RAM: Dopuszczalne, ale monitoruj przy większym obciążeniu"
else
  echo "🔥 Zużycie RAM: Wysokie! Rozważ Mikrus 3.0 (2GB RAM) lub optymalizację"
fi

echo ""
echo "💾 Szczegółowe dane: $OUTPUT_FILE"
echo ""
echo "📊 Aby wizualizować w Excelu/Google Sheets:"
echo "   1. Otwórz $OUTPUT_FILE"
echo "   2. Utwórz wykres z kolumn: timestamp, cpu_percent, memory_mb"
