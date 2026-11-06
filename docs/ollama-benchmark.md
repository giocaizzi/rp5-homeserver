# Ollama model benchmark (Raspberry Pi 5)

Goal: pick a small local model for scheduled n8n automations that call MCP tools on content (classify, extract, one tool call per run). Latency matters less than correct output and memory headroom. Procedure: [run-ollama-benchmark](./RUNBOOKS/run-ollama-benchmark.md). Code: `scripts/bench_ollama.sh`, `scripts/bench_prompts.json`. Raw data: `docs/benchmarks/ollama/`.

## Setup under test

- Raspberry Pi 5, 8 GB, 4 cores, CPU-only inference, Ollama in the `ai_llm` Swarm service (limit 3G, reservation 2G, see [services/ai](../services/ai/docker-compose.yml)).
- Server env: `OLLAMA_CONTEXT_LENGTH=4096`, `OLLAMA_FLASH_ATTENTION=1`, `OLLAMA_KV_CACHE_TYPE=q8_0`, `OLLAMA_NUM_PARALLEL=1`, `OLLAMA_MAX_LOADED_MODELS=1`.
- The other stacks keep running during the test, so free RAM is low by design (about 3 GB available): the benchmark measures what is usable in production, not a clean board. Each `.meta` file records Ollama version, env, CPU governor, temperature and RAM at the start.

## Candidates

| Model | Source | Notes |
|---|---|---|
| `granite4.2:3b` | Ollama library | Tool calling tag, Apache 2.0. |
| `gemma4:e2b` | Ollama library | 4.6 GB on disk, larger than the 3G container limit. |
| `minicpm5-2b` | Official GGUF imported with a `Modelfile` | See "Model sources". |

Models were chosen from Hugging Face and models.dev (2026-11-06): small (≤4B), recent, tool-calling capable. `minicpm5:2b` has no Ollama tag.

### Model sources

`minicpm5-2b` is built from OpenBMB's official `MiniCPM5-2B-Q4_K_M.gguf` (ModelScope repo `OpenBMB/MiniCPM5-2B-GGUF`, 1,561,318,368 bytes, Apache 2.0). Check the file against the SHA-256 published by the repo's file list before `ollama create`. The `Modelfile` is the one from OpenBMB's Ollama guide: a basic ChatML `TEMPLATE`, stops on `<|im_end|>` and `</s>`, `temperature 1.0`, `top_p 0.95`, `num_ctx 8192`. That template has **no tool section** and MiniCPM5 emits XML-style tool calls (OpenBMB recommends SGLang with its `minicpm5` parser), so a failed tool-call case was expected. It did not fail: Ollama 0.40.15 returned a parsed `tool_calls` entry (`create_note` with both arguments) in all three tool-call requests made (baseline, tuned, one manual check). The reason (a built-in parser for the model's format, or the template in the GGUF) was not investigated; OpenBMB's guide was written for Ollama 0.24.

## Method

- **Modes.** `baseline`: server defaults and each model's own defaults, no per-request options. `tuned`: per request `num_ctx=2048`, `num_thread=4`, `temperature=0.1`, `num_predict=256`, `think=false`.
- **Cases** (`scripts/bench_prompts.json`, ASCII only): `classify` (one-word sentiment), `extract_json` (JSON with keys `title`, `author`, `year`), `tool_call` (call `create_note` with `title` and `content`, among two tools).
- **Repetitions.** `RUNS` rounds (default 3) over all cases, per model, models one after another. Before each model the previous one is unloaded (`keep_alive: 0`), so the first request of a model is a cold start; later requests are warm (`keep_alive` 10 minutes).
- **Transport.** The Ollama image has no `curl`: the script sends HTTP/1.0 requests with `bash /dev/tcp` inside the container, via `ssh` and `docker exec`, non-streaming `/api/chat`. Per-request timeout 300 s (`REQ_TIMEOUT`); a timeout is recorded as a failed row of zeros.
- **Correctness (`ok`).** `classify`: the answer contains `negative` or `neutral`. `extract_json`: the reply (code fences stripped) parses as an object with all three keys. `tool_call`: the first `tool_calls` entry is `create_note` with both arguments. The check is structural, not semantic: it does not verify the extracted values.
- **Metrics.** From Ollama's response: `load_s` (load duration), `prefill_tps` (prompt tokens over prompt-eval time), `gen_tps` (generated tokens over eval time), `gen_tokens`, `total_s`. The summary averages over all rows of a model; `cold_s` is the load time of its first request.
- **Confounders to keep in mind.** Thinking models spend most tokens on reasoning in `baseline` (`gen_tokens` shows it), so `total_s` is dominated by output length, not speed; `minicpm5-2b` runs with `num_ctx 8192` in `baseline` while the others use 4096; three rounds is a small sample and the Pi has other workloads; results change with CPU temperature and governor.

## Netdata metrics

Collected from Netdata (node `rp5-homeserver`) over the run window: from the first `ts` of the TSV to `end_utc` in the `.meta` file, one window per model.

| Context | What it shows |
|---|---|
| `system.cpu` | host CPU use (user, system, iowait) |
| `cgroup.cpu`, `cgroup.mem_usage` | CPU and memory of the `ai_llm` container against its 3G limit |
| `cgroup.throttled` | CPU throttling of the container |
| `system.ram`, `mem.swap`, `mem.swapio` | host free RAM and swap pressure |
| `app.cpu_utilization` (`ollama`) | the Ollama process |
| `system.hw.sensor.temperature.input` (`cpu_thermal`) | SoC temperature; also check `vcgencmd get_throttled` |

## Results

Run of 2026-11-06, Ollama 0.40.15, `RUNS=1` (one round of the three cases per model, so 3 requests per model and mode): **a small sample, indicative only**. Raw data: [`docs/benchmarks/ollama/`](./benchmarks/ollama/) (`baseline_20261106T175157Z`, `tuned_20261106T180005Z`, each with `.tsv` and `.meta`).

### Baseline (server and model defaults)

| Model | gen tok/s | prefill tok/s | mean s/request | correct | cold load s | mean tokens generated |
|---|---|---|---|---|---|---|
| `gemma4:e2b` | 9.6 | 74.3 | 37.5 | 3/3 | 29.8 | 246 |
| `minicpm5-2b` | 6.0 | 41.7 | 48.9 | 2/3 | 7.4 | 254 |
| `granite4.2:3b` | 3.9 | 24.8 | 64.6 | 3/3 | 10.4 | 212 |

### Tuned (`num_ctx=2048`, `num_thread=4`, `temperature=0.1`, `num_predict=256`, `think=false`)

| Model | gen tok/s | prefill tok/s | mean s/request | correct | cold load s | mean tokens generated |
|---|---|---|---|---|---|---|
| `gemma4:e2b` | 10.3 | 74.8 | 12.9 | 3/3 | 29.4 | 22 |
| `minicpm5-2b` | 8.9 | 37.6 | 9.5 | 3/3 | 7.1 | 20 |
| `granite4.2:3b` | 6.1 | 26.9 | 16.6 | 3/3 | 10.6 | 27 |

Reading:
- The speed gain of `tuned` is mostly shorter output: with thinking off the models answer in 2 to 48 tokens instead of 62 to 489, and request time drops by 3 to 5 times. Per-token speed also rises for Granite and MiniCPM (3.9 to 6.1 and 6.0 to 8.9 tok/s); part of that is noise and CPU temperature (see below).
- `minicpm5-2b` failed `classify` once in baseline (489 tokens at `temperature 1.0`, with thinking) and passed it in a manual rerun with baseline options (173 tokens, answer `neutral`): at `temperature 1.0` the result varies between runs. It is the model's own default; `tuned` removes it.
- `gemma4:e2b` is the fastest but its cold start is the slowest (about 30 s, 4.6 GB read from disk), and it reaches the 3 GB container limit (see Netdata). `minicpm5-2b` is the lightest.
- Tool calling worked for all three models in every run; with one request per mode this says nothing about reliability with several tools or longer prompts.
- With `RUNS=1` correctness cannot separate the models: all three are 100% in `tuned`. Repeat with `RUNS=3` or more cases before choosing on quality.

### Netdata data (node `rp5-homeserver`)

Baseline windows (per-minute buckets, maximum of the bucket for memory and temperature, average for CPU):

| Model | Window (UTC) | Container CPU (100% = 1 core) | Container RAM max | Container swap | CPU temp |
|---|---|---|---|---|---|
| `granite4.2:3b` | 17:51:58 to 17:55:13 | about 360% | 2.4 GB | 0 | 72.6 to 82.6 °C |
| `minicpm5-2b` | 17:55:14 to 17:57:41 | about 365% | 1.8 GB | 0 | 77.2 to 83.2 °C |
| `gemma4:e2b` | 17:57:42 to 17:59:36 | 210 to 330% | 3.0 GB (limit 3 GB) | 0 | 78.9 to 81.5 °C |

Tuned run (18:00:06 to 18:02:07, whole run, 33 s buckets): container CPU 145 to 285% (average 211%), container RAM 1.7 to 3.0 GB, CPU temp 73.3 to 77.9 °C. Host CPU in the 8 minutes of the baseline: 46% user on average, 96% at peak (4 cores).

Host state around the runs: `vcgencmd get_throttled` went from `0x0` before to `0xe0000` after the baseline (soft temperature limit, frequency cap and throttling occurred since boot; none active at the time of reading), peak 83.2 °C, load average 5.4 on 4 cores, free RAM about 100 MB and system swap up from 2.4 to 3.3 GB during the baseline. All Swarm services stayed at their desired replicas, none unhealthy, no OOM line in the kernel log. Latency of the MCP endpoints was not measured. The baseline numbers were taken while the SoC was at or near its thermal limit, so tok/s are conservative and depend on cooling.

### Conclusions so far

- For small scheduled tasks, run in `tuned` mode: short output, thinking off, low temperature. A request then takes about 4 to 17 s warm.
- `gemma4:e2b` is the fastest warm and `minicpm5-2b` the lightest and quickest to start; `granite4.2:3b` is the slowest but the most conventional (official Ollama tag, tool-calling tag). A final choice needs a larger sample (several rounds, more cases, a real MCP tool from n8n).
- Heat is the limiting factor on this board: check the cooler before scheduling regular runs.

## Optimizations considered

Applied per request in `tuned` (no repo change): smaller context, explicit thread count, low temperature, capped output, thinking off. To evaluate after the numbers: CPU governor `performance` (host change), `OLLAMA_KEEP_ALIVE`, removing the unused `chat` service from the stack, a larger container limit, and `llama-server` as an alternative runtime (reported 10 to 20 percent faster in third-party tests, unverified here).
