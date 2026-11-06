#!/usr/bin/env bash
# Benchmark small Ollama models on the Pi: speed (tok/s) and task correctness.
# Usage: PI_SSH_USER=pi ./scripts/bench_ollama.sh <baseline|tuned> <model>...
# Method and results: docs/ollama-benchmark.md; procedure: docs/RUNBOOKS/run-ollama-benchmark.md
set -euo pipefail

PI_HOST="${PI_HOST:-pi.local}"
: "${PI_SSH_USER:?set PI_SSH_USER}"
RUNS="${RUNS:-3}"
OUT="${OUT:-bench-results}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PROMPTS="${PROMPTS:-$HERE/bench_prompts.json}"

MODE="${1:?usage: $0 <baseline|tuned> <model>...}"; shift
[ "$#" -gt 0 ] || { echo "no models given" >&2; exit 2; }
case "$MODE" in
  baseline) OPTS='{}'; THINK=null ;;
  tuned) OPTS='{"num_ctx":2048,"num_thread":4,"temperature":0.1,"num_predict":256}'; THINK=false ;;
  *) echo "mode must be baseline or tuned" >&2; exit 2 ;;
esac

ssh_pi() { ssh "$PI_SSH_USER@$PI_HOST" "$@"; }
CONTAINER="$(ssh_pi 'docker ps --format "{{.Names}}"' | grep '^ai_llm' | head -1)"
[ -n "$CONTAINER" ] || { echo "ai_llm container not found" >&2; exit 1; }

# The Ollama image has no curl: speak HTTP/1.0 over bash /dev/tcp inside the container.
api() { # $1 = path; JSON body on stdin; prints the JSON response body
  local body len
  body="$(cat)"; len="$(printf %s "$body" | wc -c | tr -d ' ')"
  { printf 'POST %s HTTP/1.0\r\nContent-Type: application/json\r\nContent-Length: %s\r\n\r\n' "$1" "$len"
    printf %s "$body"; } |
    ssh_pi "docker exec -i $CONTAINER timeout "${REQ_TIMEOUT:-300}" bash -c 'exec 4<&0 3<>/dev/tcp/127.0.0.1/11434; cat <&4 >&3 & cat <&3; wait'" |
    tr -d '\r' | sed '1,/^$/d'
}

mkdir -p "$OUT"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TSV="$OUT/${MODE}_${STAMP}.tsv"
META="$OUT/${MODE}_${STAMP}.meta"
{
  echo "date_utc=$STAMP mode=$MODE runs=$RUNS options=$OPTS think=$THINK"
  ssh_pi "docker exec $CONTAINER ollama --version; docker exec $CONTAINER ollama list; docker inspect $CONTAINER --format 'env={{range .Config.Env}}{{println .}}{{end}}' | grep OLLAMA_; nproc; cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor; vcgencmd measure_temp; free -m | sed -n 2p" 2>&1
} > "$META"
printf 'ts\tmodel\tcase\trun\tload_s\tprefill_tps\tgen_tps\tgen_tokens\ttotal_s\tok\n' > "$TSV"

for model in "$@"; do
  # Unload everything so run 1 of the first case is a cold start.
  printf '{"model":"%s","keep_alive":0}' "$model" | api /api/generate >/dev/null || true
  for run in $(seq 1 "$RUNS"); do
    jq -c '.[]' "$PROMPTS" | while read -r c; do
      req="$(jq -c --arg m "$model" --argjson o "$OPTS" --argjson t "$THINK" '
        {model:$m, stream:false, keep_alive:"10m", options:$o,
         messages:((if .system then [{role:"system",content:.system}] else [] end) + [{role:"user",content:.user}])}
        + (if $t==null then {} else {think:$t} end)
        + (if .tools then {tools:.tools} else {} end)' <<<"$c")"
      ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      resp="$(printf %s "$req" | api /api/chat || true)"
      printf %s "$resp" | jq -r --arg ts "$ts" --arg m "$model" --argjson run "$run" --argjson c "$c" '
        def okc:
          if .error then false
          elif $c.check.type=="contains_any" then (.message.content|ascii_downcase) as $x | any($c.check.expect[]; . as $e | $x|contains($e))
          elif $c.check.type=="json_keys" then ((.message.content|gsub("```json|```";"")|fromjson?) as $j | ($j|type)=="object" and all($c.check.expect[]; . as $k | $j|has($k)))
          elif $c.check.type=="tool" then (.message.tool_calls[0].function) as $f | ($f.name==$c.check.expect) and all($c.check.args[]; . as $k | $f.arguments|has($k))
          else false end;
        [$ts, $m, $c.id, $run,
         ((.load_duration//0)/1e9*100|round/100),
         (if (.prompt_eval_duration//0)>0 then (.prompt_eval_count/(.prompt_eval_duration/1e9)*10|round/10) else 0 end),
         (if (.eval_duration//0)>0 then (.eval_count/(.eval_duration/1e9)*10|round/10) else 0 end),
         (.eval_count//0), ((.total_duration//0)/1e9*10|round/10), okc] | @tsv' >> "$TSV" ||
        printf '%s\t%s\t%s\t%s\t0\t0\t0\t0\t0\tfalse\n' "$ts" "$model" "$(jq -r .id <<<"$c")" "$run" >> "$TSV"
    done
  done
  printf '{"model":"%s","keep_alive":0}' "$model" | api /api/generate >/dev/null || true
done

echo "== $MODE ($STAMP): mean over runs; ok = share of correct answers"
awk -F'\t' 'NR>1 { n[$2]++; g[$2]+=$7; p[$2]+=$6; t[$2]+=$9; if($10=="true") k[$2]++; if(!($2 in l) && $4==1) l[$2]=$5 }
  END { printf "%-22s %8s %8s %8s %6s %8s\n","model","gen_tps","pref_tps","total_s","ok","cold_s";
        for (m in n) printf "%-22s %8.1f %8.1f %8.1f %5.0f%% %8.1f\n", m, g[m]/n[m], p[m]/n[m], t[m]/n[m], 100*k[m]/n[m], l[m] }' "$TSV"
echo "end_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$META"
echo "raw: $TSV  env: $META"
