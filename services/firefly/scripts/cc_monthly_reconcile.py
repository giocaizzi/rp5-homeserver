#!/usr/bin/env python3
"""Pin Carta Credito Fineco (id 3848) to zero after each monthly ESTRATTO.

Designed to run on the 11th of each month via cron inside the firefly_scheduler
container. Idempotent and defensive.

Mechanism: adjusts the account's `opening_balance` so that current_balance
collapses to zero. No reconciliation/balancing journals are created; the
single system-generated opening-balance journal is edited in place. This
keeps the ledger free of synthetic transactions and avoids maintaining a
paired reconciliation account.

Flow:
  1. Verify the most recent settlement transfer (fineco -> CC) is within the
     last 14 days. If not, log + skip (LunchFlow gap or missing ESTRATTO —
     don't blindly zero the account; surface the problem instead).
  2. Read current CC balance.
  3. If non-zero, PUT a new opening_balance = current_opening - current_balance.
     This shifts opening_balance so current_balance becomes zero.

All log output goes to stdout so `docker service logs firefly_scheduler`
surfaces it.
"""
import json, os, subprocess, sys, urllib.error, urllib.request
from datetime import datetime, timedelta, timezone

CC_ID                  = 3848
SETTLEMENT_WINDOW_DAYS = 14
APP_URL                = "http://firefly-app:8080"
TOKEN_PATH             = "/run/secrets/firefly_access_token"

def log(msg):
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"[cc_monthly_reconcile {ts}] {msg}", flush=True)

def load_token():
    try:
        with open(TOKEN_PATH) as f: return f.read().strip()
    except OSError as e:
        log(f"FATAL: cannot read token at {TOKEN_PATH}: {e}"); sys.exit(2)

def api(method, path, token, body=None):
    url = f"{APP_URL}{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Accept", "application/json")
    if data is not None: req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode() or "null")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        try: parsed = json.loads(body)
        except json.JSONDecodeError: parsed = body
        return e.code, parsed
    except urllib.error.URLError as e:
        log(f"FATAL: network error calling {url}: {e}"); sys.exit(3)

def recent_settlement(token):
    """Return (date_iso, amount, group_id, desc) of the most recent fineco->CC
    transfer in the last SETTLEMENT_WINDOW_DAYS days, or None."""
    cutoff = (datetime.now(timezone.utc) - timedelta(days=SETTLEMENT_WINDOW_DAYS)).date().isoformat()
    today = datetime.now(timezone.utc).date().isoformat()
    st, d = api("GET",
                f"/api/v1/accounts/{CC_ID}/transactions?type=transfer&start={cutoff}&end={today}&limit=50",
                token)
    if st != 200: return None
    candidates = []
    for g in d.get("data", []):
        for s in g["attributes"]["transactions"]:
            if str(s["source_id"]) == "1" and str(s["destination_id"]) == str(CC_ID):
                candidates.append((s["date"][:10], float(s["amount"]), g["id"], s.get("description") or ""))
    if not candidates: return None
    candidates.sort(reverse=True)
    return candidates[0]

def main():
    token = load_token()

    log("checking most recent ESTRATTO settlement...")
    recent = recent_settlement(token)
    if recent is None:
        log(f"SKIP: no fineco->CC transfer found in last {SETTLEMENT_WINDOW_DAYS} days. "
            f"Either LunchFlow is lagging, rule 9 misfired, or there was no ESTRATTO this cycle. "
            f"Investigate before reconciling.")
        return
    settle_date, settle_amount, settle_gid, settle_desc = recent
    log(f"found settlement: date={settle_date} amount=€{settle_amount:.2f} group={settle_gid}")
    log(f"  desc: {settle_desc[:100]}")

    log("reading CC account state...")
    st, d = api("GET", f"/api/v1/accounts/{CC_ID}", token)
    if st != 200:
        log(f"FATAL: GET /accounts/{CC_ID} returned {st}"); sys.exit(4)
    a = d["data"]["attributes"]
    cur_bal = float(a["current_balance"])
    cur_opening = float(a["opening_balance"] or 0)
    opening_date = a["opening_balance_date"]
    log(f"current_balance = {cur_bal:+.2f}  opening_balance = {cur_opening:+.2f}  (dated {opening_date[:10] if opening_date else 'n/a'})")

    if abs(cur_bal) < 0.01:
        log("balance already at 0 — nothing to do (idempotent)")
        return

    new_opening = cur_opening - cur_bal
    log(f"adjusting opening_balance: {cur_opening:+.2f} -> {new_opening:+.2f}  (delta {-cur_bal:+.2f})")

    body = {"opening_balance": f"{new_opening:.2f}", "opening_balance_date": opening_date}
    st, resp = api("PUT", f"/api/v1/accounts/{CC_ID}", token, body)
    if st not in (200, 201):
        log(f"FAIL: PUT returned {st}; response={json.dumps(resp)[:400]}")
        sys.exit(5)

    # verify
    st, d = api("GET", f"/api/v1/accounts/{CC_ID}", token)
    new_cur = float(d["data"]["attributes"]["current_balance"])
    if abs(new_cur) < 0.01:
        log(f"OK: opening_balance updated; current_balance now {new_cur:+.2f}")
    else:
        log(f"WARN: opening_balance updated but current_balance={new_cur:+.2f} (expected 0); investigate")
        sys.exit(6)

if __name__ == "__main__":
    main()
