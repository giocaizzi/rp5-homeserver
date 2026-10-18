#!/usr/bin/env bash
# Import credit-card rows into Firefly from bank exports, then recompute the card cycle residuals.
#
# Usage: PI_SSH_USER=pi ./scripts/firefly_cc_import.sh <file.xls|file.xlsx> [...]
#
# Accepts the card's monthly statement (.xls: "Data operazione", "Data registrazione",
# "Descrizione", "Importo") and the current-account movements export (.xlsx: card rows
# whose "Descrizione" starts with CC_ROW_PREFIX). Files are parsed locally (uv, pinned
# xlrd/openpyxl); only normalized rows travel to the Pi, where firefly_jobs.py cc-import
# posts them (stable external ids, so re-running a file adds nothing).
#
# Environment:
#   PI_SSH_USER   - SSH username for the Pi (required)
#   PI_HOST       - Pi hostname or IP (default: pi.local)
#   CC_ROW_PREFIX - movements-export "Descrizione" prefix of card rows (required for .xlsx)
set -euo pipefail

: "${PI_SSH_USER:?set PI_SSH_USER}"
PI_HOST="${PI_HOST:-pi.local}"
[ $# -ge 1 ] || { echo "usage: $0 <file.xls|file.xlsx> [...]" >&2; exit 1; }

rows=$(CC_ROW_PREFIX="${CC_ROW_PREFIX:-}" uv run -q --no-project \
  --with xlrd==2.0.1 --with openpyxl==3.1.5 python -I -W ignore - "$@" <<'PY'
import datetime as dt, json, os, sys

def iso(v):
    if isinstance(v, (int, float)):  # Excel serial date
        return (dt.date(1899, 12, 30) + dt.timedelta(days=int(v))).isoformat()
    if isinstance(v, dt.datetime):
        return v.date().isoformat()
    return None

out = []
for path in sys.argv[1:]:
    if path.lower().endswith(".xls"):
        import xlrd
        sh = xlrd.open_workbook(path).sheet_by_index(0)
        grid = [sh.row_values(i) for i in range(sh.nrows)]
    else:
        import openpyxl
        grid = [list(r) for r in openpyxl.load_workbook(path, read_only=True, data_only=True).worksheets[0].iter_rows(values_only=True)]
    head = next(i for i, r in enumerate(grid) if "Data operazione" in r or "Data_Operazione" in r)
    cols = {str(c): j for j, c in enumerate(grid[head]) if c}
    n0 = len(out)
    for r in grid[head + 1:]:
        if "Data operazione" in cols:  # card statement
            d, b = iso(r[cols["Data operazione"]]), iso(r[cols["Data registrazione"]])
            if not d or str(r[cols["Stato operazione"]]).lower() != "contabilizzato":
                continue
            out.append(dict(date=d, booked=b or d, amount=float(r[cols["Importo"]]), description=str(r[cols["Descrizione"]]).strip()))
        else:  # current-account movements export: card rows only
            if not os.environ["CC_ROW_PREFIX"]:
                sys.exit(f"{path}: set CC_ROW_PREFIX to the card rows' Descrizione prefix")
            if not str(r[cols["Descrizione"]] or "").startswith(os.environ["CC_ROW_PREFIX"]) or r[cols["Stato"]] != "Contabilizzato":
                continue
            d = iso(r[cols["Data_Operazione"]]) or iso(r[cols["Data_Valuta"]])
            amount = (r[cols["Entrate"]] or 0) + (r[cols["Uscite"]] or 0)
            out.append(dict(date=d, booked=iso(r[cols["Data_Valuta"]]) or d, amount=float(amount), description=str(r[cols["Descrizione_Completa"]] or "").strip()))
    print(f"{path}: {len(out) - n0} card rows", file=sys.stderr)
print(json.dumps(out))
PY
)

# shellcheck disable=SC2029  # the container lookup must run on the Pi
ssh "${PI_SSH_USER}@${PI_HOST}" \
  'docker exec -i "$(docker ps -qf label=com.docker.swarm.service.name=firefly_scheduler | head -1)" python3 /usr/local/bin/firefly_jobs.py cc-import' \
  <<<"$rows"
