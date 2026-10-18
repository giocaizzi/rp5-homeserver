#!/usr/bin/env python3
"""Firefly III scheduled jobs: credit-card cycle residuals, bank-balance check, card import.

Runs inside the firefly_scheduler container (stdlib only, HTTP to firefly-app).

  firefly_jobs.py daily       daily, after the bank-data auto-import
  firefly_jobs.py cc-import   card rows as JSON on stdin: [{"date","booked","amount","description"}]

Ledger model, checks and alerts: docs/firefly.md. Nothing private lives here:
account ids, bank wording and tags come from the stack env and the importer config.
"""
import base64, hashlib, json, os, re, sys, time, urllib.error, urllib.parse, urllib.request
from datetime import date, datetime, timedelta, timezone
from typing import Any

APP = "http://firefly-app:8080/api/v1"
TOKEN_PATH = "/run/secrets/firefly_access_token"
PROVIDER_KEY_PATH = "/run/secrets/lunch_flow_api_key"
PROVIDER_API = "https://lunchflow.app/api/v1"
IMPORTER_CONFIG = os.environ.get("IMPORTER_CONFIG", "/etc/firefly/importer.json")
NTFY_URL = os.environ.get("NTFY_URL", "http://ntfy_app/firefly")
NTFY_TOKEN_PATH = "/run/secrets/ntfy_token"
# Word before the statement close date in the settlement description ("<marker> dd/mm/yy");
# unset: the cycle closes on the last day of the previous month
CLOSE_MARKER = os.environ.get("CC_CLOSE_MARKER", "")
CLOSE_RE = re.compile(rf"\b{re.escape(CLOSE_MARKER)} (\d{{2}}/\d{{2}}/\d{{2,4}})\b") if CLOSE_MARKER else None
# List values accept ";" as well as ",": Portainer cuts swarm stack env values at the first comma
SKIP_PREFIXES = tuple(p for p in re.split(r"[;,]", os.environ.get("CC_IMPORT_SKIP_PREFIXES", "")) if p)
REVIEW_TAGS = [t for t in re.split(r"[;,]", os.environ.get("REVIEW_TAGS", "")) if t]
CYCLES_TO_CHECK = 4
TOKEN_WARN_DAYS = 30
RESIDUAL_TAG = "cc-residual"
CARD_TAG = "cc-itemized"


def log(msg):
    print(f"[firefly_jobs {datetime.now(timezone.utc):%Y-%m-%dT%H:%M:%SZ}] {msg}", flush=True)


def env_id(name):
    v = os.environ.get(name, "")
    if not v.isdigit():
        log(f"FATAL: {name} must be a Firefly account id"); sys.exit(1)
    return v


def read(path):
    with open(path) as f:
        return f.read().strip()


TOKEN = read(TOKEN_PATH)


def http(method, url, headers, body=None) -> tuple[int, Any]:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read().decode()
            return r.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", errors="replace")[:500]


def ff(method, path, body=None):
    return http(method, APP + path, {"Authorization": f"Bearer {TOKEN}", "Accept": "application/json"}, body)


def ff_pages(path):
    out, page = [], 1
    while True:
        sep = "&" if "?" in path else "?"
        st, d = ff("GET", f"{path}{sep}limit=200&page={page}")
        if st != 200:
            raise RuntimeError(f"GET {path}: {st} {d}")
        out += d["data"]
        if page >= d["meta"]["pagination"]["total_pages"]:
            return out
        page += 1


def splits(account_id, start, end):
    """All splits touching the account between start and end (inclusive), with group id."""
    rows = []
    for g in ff_pages(f"/accounts/{account_id}/transactions?start={start}&end={end}"):
        for s in g["attributes"]["transactions"]:
            rows.append(dict(s, group_id=g["id"]))
    return rows


# ---------------------------------------------------------------- card residuals
def close_date(desc, posted):
    m = CLOSE_RE.search(desc or "") if CLOSE_RE else None
    if m:
        d = m.group(1)
        return datetime.strptime(d, "%d/%m/%y" if len(d) == 8 else "%d/%m/%Y").date()
    return posted.replace(day=1) - timedelta(days=1)  # last day of the previous month


def booked(s):
    """Card rows carry the statement registration date as book_date; it decides the cycle."""
    return date.fromisoformat((s.get("book_date") or s["date"])[:10])


def card_residuals(alerts):
    card, settle, residual_acct = env_id("CC_ACCOUNT_ID"), env_id("CC_SETTLEMENT_SOURCE_ID"), env_id("CC_RESIDUAL_ACCOUNT_ID")
    today = date.today()
    rows = splits(card, (today - timedelta(days=62 * (CYCLES_TO_CHECK + 1))).isoformat(), today.isoformat())
    stmts = sorted(
        (close_date(s["description"], date.fromisoformat(s["date"][:10])), float(s["amount"]), s)
        for s in rows if str(s["source_id"]) == settle and str(s["destination_id"]) == card)
    for (prev, _, _), (close, amount, _) in list(zip(stmts, stmts[1:]))[-CYCLES_TO_CHECK:]:
        cycle = [s for s in rows if prev < booked(s) <= close]
        residuals = [s for s in cycle if RESIDUAL_TAG in (s.get("tags") or [])]
        spent = 0.0
        for s in cycle:
            if s in residuals or (str(s["source_id"]) == settle and str(s["destination_id"]) == card):
                continue
            spent += float(s["amount"]) if str(s["source_id"]) == card else -float(s["amount"])
        want = round(amount - spent, 2)
        have = round(sum(float(s["amount"]) for s in residuals), 2)
        label = f"cycle to {close}: statement {amount:.2f}, itemized {spent:.2f}"
        if want < -0.005:
            alerts.append(f"Card {label}: itemized exceeds the statement by {-want:.2f}")
            continue
        if abs(want - have) < 0.005 and len(residuals) <= 1:
            continue
        for s in residuals:
            ff("DELETE", f"/transactions/{s['group_id']}")
        if want > 0.005:
            st, d = ff("POST", "/transactions", dict(apply_rules=False, fire_webhooks=False, transactions=[dict(
                type="withdrawal", date=close.isoformat(), amount=f"{want:.2f}",
                description=f"Credit card - unitemized spending (statement {close})",
                source_id=card, destination_id=residual_acct, tags=[RESIDUAL_TAG],
                notes=f"Residual = statement {amount:.2f} - itemized {spent:.2f}. Recomputed by firefly_jobs.py.")]))
            if st != 200:
                alerts.append(f"Card {label}: posting residual failed ({st})"); continue
        log(f"card {label}: residual {have:.2f} -> {max(want, 0):.2f}")


# ---------------------------------------------------------------- bank-data checks
def provider(path):
    st, d = http("GET", f"{PROVIDER_API}/{path}", {"x-api-key": read(PROVIDER_KEY_PATH), "Accept": "application/json"})
    if st != 200:
        raise RuntimeError(f"provider {path}: {st}")
    return d


def balance_check(alerts):
    mapping = json.load(open(IMPORTER_CONFIG)).get("accounts", {})
    status = {str(a["id"]): a for a in provider("accounts").get("accounts", [])}
    today = date.today()
    for pid, fid in mapping.items():
        acc = status.get(str(pid))
        if not acc:
            alerts.append(f"Bank-data account {pid} is mapped but no longer listed by the provider"); continue
        name = acc.get("name", pid)
        if acc.get("status") != "ACTIVE":
            alerts.append(f"{name}: connection status {acc.get('status')} (renew the bank consent)")
        bal = provider(f"accounts/{pid}/balance").get("balance", {})
        st, d = ff("GET", f"/accounts/{fid}")
        if st != 200:
            alerts.append(f"{name}: Firefly account {fid} missing ({st})"); continue
        mine = float(d["data"]["attributes"]["current_balance"])
        if abs(mine - float(bal.get("amount", 0))) > 0.005:
            alerts.append(f"{name}: bank {bal.get('amount')} {bal.get('currency', '')} vs Firefly {mine:.2f}")
        txs = [t for t in provider(f"accounts/{pid}/transactions").get("transactions", []) if float(t.get("amount") or 0)]
        if txs:
            last_bank = max(t["date"][:10] for t in txs)
            mine_rows = splits(fid, (today - timedelta(days=30)).isoformat(), today.isoformat())
            last_mine = max((s["date"][:10] for s in mine_rows), default="none")
            if last_mine == "none" or date.fromisoformat(last_bank) > date.fromisoformat(last_mine) + timedelta(days=1):
                alerts.append(f"{name}: provider has transactions up to {last_bank}, Firefly up to {last_mine} (import behind)")


def token_check(alerts):
    try:
        payload = TOKEN.split(".")[1]
        exp = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))["exp"]
    except (IndexError, KeyError, ValueError):
        return
    days = (datetime.fromtimestamp(exp, timezone.utc) - datetime.now(timezone.utc)).days
    if days < TOKEN_WARN_DAYS:
        alerts.append(f"Firefly API token expires in {days} days: rotate firefly_access_token (README)")


def review_summary():
    if not REVIEW_TAGS or date.today().weekday() != 0:
        return []
    out = []
    for tag in REVIEW_TAGS:
        st, d = ff("GET", f"/tags/{urllib.parse.quote(tag)}/transactions?limit=1&start={(date.today() - timedelta(days=90)).isoformat()}")
        n = d["meta"]["pagination"]["total"] if st == 200 else 0
        if n:
            out.append(f"{n} transaction(s) tagged {tag} in the last 90 days")
    return out


def notify(title, lines, priority):
    if not lines:
        return
    try:
        req = urllib.request.Request(NTFY_URL, data="\n".join(lines).encode(), method="POST", headers={
            "Authorization": f"Bearer {read(NTFY_TOKEN_PATH)}", "Title": title, "Priority": str(priority), "Tags": "moneybag"})
        urllib.request.urlopen(req, timeout=30).close()
    except (urllib.error.URLError, OSError) as e:
        log(f"ntfy failed: {e}")


def daily():
    alerts = []
    for job in (card_residuals, balance_check, token_check):
        try:
            job(alerts)
        except Exception as e:  # one failing job must not hide the others
            alerts.append(f"{job.__name__} failed: {e}")
    for a in alerts:
        log(f"ALERT {a}")
    notify("Firefly needs attention", alerts, 4)
    notify("Firefly weekly review", review_summary(), 2)
    log(f"done, {len(alerts)} alert(s)")


# ---------------------------------------------------------------- card import
def cc_import():
    """stdin: [{"date","booked","amount","description"}], amount signed (purchase < 0)."""
    card = env_id("CC_ACCOUNT_ID")
    rows = json.load(sys.stdin)
    if not rows:
        log("no rows"); return
    lo = min(r["date"] for r in rows)
    hi = max(r["date"] for r in rows)
    existing = splits(card, (date.fromisoformat(lo) - timedelta(days=3)).isoformat(), hi)
    ext_ids = {s.get("external_id") for s in existing}
    seen, posted, skipped = {}, 0, 0
    for r in rows:
        desc, amount = r["description"].strip(), float(r["amount"])
        key = f'{r["date"]}|{r["booked"]}|{amount:.2f}|{desc}'
        seen[key] = seen.get(key, 0) + 1
        ext = "cc:" + hashlib.sha1(f"{key}|{seen[key]}".encode()).hexdigest()[:24]
        if desc.startswith(SKIP_PREFIXES) or ext in ext_ids:
            skipped += 1; continue
        same = [s for s in existing if s["date"][:10] == r["date"] and abs(float(s["amount"]) - abs(amount)) < 0.005
                and RESIDUAL_TAG not in (s.get("tags") or []) and not s.get("_used")]
        if same:  # already booked from another export format
            same[0]["_used"] = True; skipped += 1; continue
        name = re.sub(r"\s+[A-Z]{2}$", "", desc)[:60] or "Credit card"
        tx = dict(date=r["date"], book_date=r["booked"], amount=f"{abs(amount):.2f}", description=desc,
                  external_id=ext, tags=[CARD_TAG])
        tx.update(dict(type="withdrawal", source_id=card, destination_name=name) if amount < 0
                  else dict(type="deposit", source_name=name, destination_id=card))
        st, d = ff("POST", "/transactions", dict(apply_rules=True, fire_webhooks=False, error_if_duplicate_hash=True, transactions=[tx]))
        if st == 200:
            posted += 1
        else:
            log(f"skip {r['date']} {amount:.2f}: {st} {str(d)[:200]}")
    log(f"card import: {posted} posted, {skipped} skipped of {len(rows)}")
    alerts = []
    card_residuals(alerts)
    for a in alerts:
        log(f"ALERT {a}")


if __name__ == "__main__":
    {"daily": daily, "cc-import": cc_import}.get(sys.argv[1] if len(sys.argv) > 1 else "", lambda: sys.exit("usage: firefly_jobs.py daily|cc-import"))()
