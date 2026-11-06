# Run the Ollama model benchmark

**When:** you want to compare small local models (speed, memory, task correctness) on the Pi before choosing one for automations, or re-check after a model, Ollama or stack change. Method and results: [docs/ollama-benchmark.md](../ollama-benchmark.md).
**Preconditions:** SSH to the Pi (`PI_SSH_USER`, `PI_HOST` default `pi.local`), the `ai` stack deployed with the `llm` service running, `jq` on the machine running the script, and the candidate models present in Ollama (`ollama list` inside the container).

## Steps
1. Make sure nothing else heavy runs on the Pi (the result depends on free CPU and RAM), then note the time (UTC) for the Netdata window.
2. Pull the models (name must match what you pass to the script):
   ```bash
   ssh pi@pi.local 'docker exec "$(docker ps -qf label=com.docker.swarm.service.name=ai_llm | head -1)" ollama pull <model>'
   ```
   A model without an Ollama tag is imported from a GGUF with a `Modelfile` (see the method doc, "Model sources").
3. Baseline run (server defaults):
   ```bash
   PI_SSH_USER=pi RUNS=3 OUT=docs/benchmarks/ollama ./scripts/bench_ollama.sh baseline <model> [<model>...]
   ```
4. Tuned run (per-request options: `num_ctx=2048`, `num_thread=4`, `temperature=0.1`, `num_predict=256`, `think=false`):
   ```bash
   PI_SSH_USER=pi RUNS=3 OUT=docs/benchmarks/ollama ./scripts/bench_ollama.sh tuned <model> [<model>...]
   ```
5. Collect the Netdata metrics for the run window (`ts` column of the TSV to `end_utc` in the `.meta` file), see the method doc, "Netdata metrics".
6. Add the summary tables to [docs/ollama-benchmark.md](../ollama-benchmark.md) and commit the `.tsv` and `.meta` files.

## Verify
The script ends with one summary table per mode (`gen_tps`, `pref_tps`, `total_s`, `ok`, `cold_s`) and the path of the raw files. Every row of the TSV has a non-zero `gen_tps`; a row of zeros means the request failed or hit `REQ_TIMEOUT` (default 300 s).

## Rollback
Nothing is changed on the Pi except downloaded models. Remove one with `docker exec <ai_llm container> ollama rm <model>`. Delete the temporary GGUF and `Modelfile` from the Pi if you imported one.

**Last verified:** 2026-11-06 by Claude Code (baseline and tuned run end to end with `RUNS=1`; `OUT` pointed at a scratch directory, not `docs/benchmarks/ollama`)
