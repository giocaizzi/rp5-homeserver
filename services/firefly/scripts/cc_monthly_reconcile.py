#!/usr/bin/env python3
"""Pin Carta Credito Fineco (id 3848) to zero after each monthly ESTRATTO.

Designed to run on the 11th of each month via cron inside the firefly_scheduler
container. Idempotent and defensive:

  1. Verify the most recent settlement transfer (fineco -> CC) is within the
     last 14 days. If not, log + skip (LunchFlow gap or missing ESTRATTO —
     don't blindly zero the account; surface the problem instead).
  2. Read current CC balance.
  3. If non-zero, post a native reconciliation transaction (source = paired
     reconciliation account, destination = CC) bringing CC to 0, dated to the
     settlement day. If already zero, do nothing.

The reconciliation account is auto-discovered (Firefly creates one per asset
on first reconciliation). All log output goes to stdout so `docker service
logs firefly_scheduler` surfaces it.
"""
import json, os, subprocess, sys, urllib.error, urllib.request
from datetime import datetime, timedelta, timezone

CC_ID            = 3848
RECON_ACCT_HINT  = 4421
SETTLEMENT_WINDOW_DAYS = 14
APP_URL          = "http://firefly-app:8080"
TOKEN_PATH       = "/run/secrets/firefly_access_token"

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

def find_recon_account(token):
    """Return id of the reconciliation account paired with the CC asset."""
    page = 1
    while True:
        st, d = api("GET", f"/api/v1/accounts?type=reconciliation&limit=50&page={page}", token)
        if st != 200: return None
        for a in d.get("data", []):
            # the paired account shares the asset's name
            if a["attributes"]["name"] == "Carta Credito Fineco":
                return int(a["id"])
        meta = (d.get("meta") or {}).get("pagination") or {}
        if page >= meta.get("total_pages", 1): break
        page += 1
    return None

def recent_settlement(token):
    """Return (date_iso, amount, group_id) of the most recent fineco->CC
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

    log("reading CC balance...")
    st, d = api("GET", f"/api/v1/accounts/{CC_ID}", token)
    if st != 200:
        log(f"FATAL: GET /accounts/{CC_ID} returned {st}"); sys.exit(4)
    cc_balance = float(d["data"]["attributes"]["current_balance"])
    log(f"CC balance = {cc_balance:+.2f}")

    if abs(cc_balance) < 0.01:
        log("balance already at 0 — nothing to do (idempotent)")
        return

    amount = -cc_balance  # +ve to bring negative balance up to 0
    log(f"reconciliation amount = {amount:.2f} EUR")

    recon_id = find_recon_account(token)
    if recon_id is None:
        log(f"reconciliation account not found by name; falling back to hint id={RECON_ACCT_HINT}")
        recon_id = RECON_ACCT_HINT
    log(f"reconciliation account id = {recon_id}")

    if amount > 0:
        source_id, dest_id = recon_id, CC_ID
    else:
        source_id, dest_id = CC_ID, recon_id
        amount = -amount

    log(f"posting reconciliation: source={source_id} dest={dest_id} amount={amount:.2f} dated={settle_date}")
    body = {
        "transactions": [{
            "type": "reconciliation",
            "date": f"{settle_date}T12:00:00+02:00",
            "amount": f"{amount:.2f}",
            "currency_code": "EUR",
            "source_id": str(source_id),
            "destination_id": str(dest_id),
            "description": f"Auto-reconciliation post-ESTRATTO {settle_date} — pin Carta Credito Fineco to 0 (paid in full)",
            "notes": f"Triggered by monthly cron after detecting settlement group {settle_gid} of €{settle_amount:.2f}. Adjusts for any unimported CC purchases from prior cycles."
        }],
        "apply_rules": False,
        "fire_webhooks": False,
        "error_if_duplicate_hash": True
    }
    st, resp = api("POST", "/api/v1/transactions", token, body)
    if st in (200, 201):
        gid = resp["data"]["id"]
        s = resp["data"]["attributes"]["transactions"][0]
        log(f"OK: reconciliation group={gid} CC balance now {s.get('destination_balance_after') or s.get('source_balance_after')}")
    else:
        log(f"FAIL: POST returned {st}; response={json.dumps(resp)[:400]}")
        sys.exit(5)

if __name__ == "__main__":
    main()
