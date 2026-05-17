---
name: firefly-logic
description: The user's personal Firefly III domain model — what each account, feed, and rule means in real life; the decisions and invariants that shape how money is recorded. Load this BEFORE doing any operational work via the `firefly` skill (which only covers the HOW). Use whenever the user asks about their money, accounts, balances, Revolut, credit card statements, salary, rent, subscriptions, categorization, or any "fix my Firefly" task — even when they don't name a stack. The `firefly` skill knows the buttons; this skill knows what they're supposed to mean.
---

# Firefly logic — user's personal domain model

This skill captures the user's high-level mental model of their Firefly III instance. It is intentionally *not* operational: how to call the API, where the importer config lives, how to rotate secrets — all that lives in the sibling `firefly` skill. Read this first to know what the moving parts *mean*, then go there to act.

The instance is single-user (`giocaizzi@gmail.com`), Italian context (descriptions and merchant names are mixed Italian/English), EUR-default.

## 1. The accounts in real life

| Firefly account | id | type | What it actually is |
|---|---:|---|---|
| `fineco` | 1 | asset (EUR) | Primary Fineco current account. The hub: salary lands here, all SDD direct debits and card top-ups go out from here. Source of truth via LunchFlow feed. |
| `revolut` | 5 | asset (EUR) | Revolut EUR wallet. Funded by Fineco top-ups (debit or credit card via Apple Pay). Used for daily card spending. Source of truth via LunchFlow feed. |
| `Carta Credito Fineco` | 3848 | ccAsset (EUR) | Fineco credit card. Statement settles around the 10th of the following month via `fineco → Carta Credito Fineco` transfer ("ESTRATTO CONTO AL …"). Manual CSV imports only — see §3. |
| `Revolut USD` | 3821 | asset (USD) | Small USD wallet, occasionally used for travel. Kept. |
| `revolut GBP` | 1025 | asset (GBP) | Dormant (last activity Feb 2024). One legacy £2.38 exchange transaction. |
| `Findomestic` | 4104 | liability (loan) | Open consumer loan. Monthly SDD repayment from Fineco. |

Cards in active use:
- **Fineco debit** ends `*9467` (truncated to `*467` in some statements)
- **Fineco credit** ends `*3488`
- Any other last-4 (`*9123`, `*3362`, `*946`, …) is old/tokenized/internal — never assume it maps to a current physical card.

## 2. Data sources and what they're trusted for

| Source | What it feeds | Reliable for |
|---|---|---|
| **LunchFlow** (`firefly_importer` auto-import) | `fineco` EUR, `revolut` EUR | Continuous, authoritative current activity. New transactions land via `POST /autoimport`. |
| **Manual CSV** (`services/firefly/config/conifg_credit.json`) | `Carta Credito Fineco` | Categorisation only — imports are sporadic ("when I remember"). **Balance is never authoritative.** |
| **Manual entry / UI** | Anything | Used to fill gaps and to fix one-off mismatches. |

**Stationary-balance invariant:** every asset balance must match the bank app at any point in time. When that breaks, **adjust the account's `opening_balance` field** (one PUT on the genesis journal) — do not insert reconciliation transactions, do not create placeholder withdrawals/deposits, do not use a `Cash account` plug.

LunchFlow may occasionally miss a transaction (small purchases, intermittent connection); over months that drifts. If you notice Firefly diverging from the bank app, edit the opening_balance to absorb the gap.

## 2a. Drift correction via opening_balance — the only mechanism

This applies to **every asset** (fineco, revolut, CC, USD/GBP wallets). One pattern, no exceptions:

```
new_opening = current_opening - (current_balance - target_balance)
```

- `target_balance` = whatever the bank app currently says (for CC: 0 right after each ESTRATTO).
- `current_opening` = the asset's current `opening_balance` field.
- API: `PUT /api/v1/accounts/{id}` with `{ "opening_balance": "<new>", "opening_balance_date": "<unchanged>" }`. Edits the existing system-generated genesis journal in place.

**Why this and not reconciliation transactions:**
- No synthetic-looking journals appear in the ledger.
- No paired reconciliation accounts to recreate or manage.
- One mechanism, applied identically for the one-time historical drift cleanup and the ongoing CC monthly pin.

**What you give up:** a per-correction journal as audit trail. The audit trail instead lives in `docker service logs firefly_scheduler` for the CC cron, and in this skill / project memory for one-off edits.

**Trigger pattern by account:**
- `fineco`, `revolut`: manual when divergence noticed (no fixed schedule — these are continuously variable).
- `Carta Credito Fineco`: automatic on the 11th of every month via the cron in §3 (real CC balance ≈ 0 right after each ESTRATTO is the known checkpoint).

Don't try to find the missing/extra transactions to reverse one-by-one — drift accumulates from hundreds of tiny gaps over years and chasing each costs more than it's worth. The opening_balance edit re-establishes a known-good point and you carry on.

## 3. The credit card mental model

`Carta Credito Fineco` (3848) is an `asset` with `account_role: ccAsset`. Negative balance = money owed to the bank.

### How the money actually flows

1. Card purchases accumulate during the month. LunchFlow does **not** see them — Fineco's API doesn't expose intra-cycle CC purchases. They are invisible to Firefly until the user manually imports a CSV.
2. On ~10th of the following month, Fineco posts a single **`ESTRATTO CONTO AL …`** debit on the main account that pays the entire prior-month statement. This is visible via LunchFlow and lands on Firefly as a `fineco → Carta Credito Fineco` **transfer** (thanks to rule 9 — see below).
3. The user pays in full each cycle. Real bank-side CC balance is therefore ≈ 0 right after each settlement, drifting negative as new purchases accumulate over the next ~30 days.

### How it's modelled

| Real-world event | Firefly journal | Source |
|---|---|---|
| CC purchase | `Carta Credito Fineco → <Merchant>` withdrawal | CSV import (sporadic) |
| Apple-Pay top-up to Revolut funded via CC | `Carta Credito Fineco → revolut` transfer | CSV import |
| Refund / chargeback | `Rimborsi → Carta Credito Fineco` deposit | CSV import (canonical revenue = `Rimborsi`; never create per-merchant revenue accounts for refunds) |
| Monthly settlement | `fineco → Carta Credito Fineco` transfer | LunchFlow, routed by rule 9 |

### Rule 9 — the ESTRATTO router

`[transfer] Addebito Carta Credito Fineco` (id 9, group `System`):
- Trigger: `description_contains='CARTA DI CREDITO DI FINECOBANK'`
- Action 1: `convert_transfer='Carta Credito Fineco'` — converts the inbound withdrawal into a transfer to the CC **asset** (not an expense bucket of the same name)
- Action 2: `clear_category`
- `stop_processing: true`

If this rule loses the `convert_transfer` action, the importer silently creates a *phantom expense* account also named "Carta Credito Fineco" and the asset stops getting credited — drift accumulates fast. (This is exactly what happened between 2026-03-10 and 2026-05-17; the May 17 audit fixed rule 9 and repointed the 3 misclassified settlements to the asset.)

### Asymmetric feeds → structural drift, by design

Settlements arrive continuously and completely via LunchFlow. Purchases arrive sporadically via manual CSV. **The CC balance in Firefly lags reality between CSV imports** — that's the cost of not running a full PSD2 feed on the card. Chasing per-transaction completeness is not the goal.

### Auto-pin to 0 on the 11th of each month

A cron job in `firefly_scheduler` runs on the **11th at 04:00** (one day after each ESTRATTO) and **adjusts `opening_balance`** so current_balance collapses to exactly 0:

- Script: `services/firefly/scripts/cc_monthly_reconcile.py`.
- Mechanism: `PUT /accounts/3848` with `opening_balance = current_opening - current_balance`. No new journals are created; the existing system genesis journal is edited in place. Consistent with §2a.
- Defensive: only fires if a `fineco → CC` transfer occurred within the last 14 days. If LunchFlow lagged or the ESTRATTO never arrived, the job logs and skips instead of blindly zeroing.
- Idempotent: if the balance is already 0, it does nothing.

This means right after each settlement the CC balance shows the truth (0 = paid in full). As you upload CSVs through the next cycle, the balance drifts negative — that's "what I've categorised this cycle so far", not the real bank balance. On the next 11th, the cron re-pins to 0 by shifting opening_balance.

The opening_balance therefore becomes a *rolling drift compensator* rather than a fixed historical starting amount. That's an unusual semantic, but mechanically simplest: one field, no reconciliation accounts to maintain, no journals to manage.

### Card-number heuristics

If a description mentions card `*3488`, it belongs on `Carta Credito Fineco`. If it shows `*9467` (or `*467`), it belongs on `fineco`. Apple-Pay top-ups can be either card — use the `9123/3362/4841/7528/8976` tokens only as hints, never as ground truth.

## 4. PayPal — excluded from the model

PayPal is **not** part of the model. There is no PayPal asset account. PayPal-mediated money flows are recorded as if PayPal didn't exist:

- A purchase paid via PayPal becomes `Fineco/CC → <Merchant>` (one transaction). The fact that PayPal was the intermediary is invisible in the ledger.
- When the bank statement does not name the underlying merchant (e.g. raw `"PayPal Europe S.a.r.l. … Mand 4RNJ…/PAYP"` lines from the LunchFlow Fineco feed), the destination is the **expense account `PayPal`** (id=3234). PayPal is treated as the merchant of last resort.
- Incoming transfers from PayPal to Fineco ("INSTANT TRANSFER", "Bonifico SEPA Estero ... Banca ordinante: PayPal") come from the **revenue account `PayPal Payout`** (id=4413).
- The LunchFlow PayPal connection was permanently removed; no PayPal-side transactions are imported.

The rules currently encoding this:
- **Rule 428** `[passthrough] PayPal SDD (no merchant) → expense:PayPal` — triggers on `description_contains=LU96ZZZ0000000000000000058`, sets destination=`PayPal` expense, stops processing.
- **Rule 429** `[income] PayPal Payout (INSTANT TRANSFER / SEPA Estero)` — triggers on transaction_type=Deposit + `description_contains=PayPal (Europe)`, sets source=`PayPal Payout`, category=`trasferimenti personali`.
- Merchant-specific PayPal rules (e.g. `description_contains=Paypal *cloudflare` → Cloudflare, `Paypal *enelenergia` → Enel Energia, `Paypal *tradeinnret` → Tradeinn, etc.) remain active — they fire *before* the generic SDD catch and resolve the real merchant when the description carries it.

The remaining PayPal-named entities are all either merchant buckets or routing helpers, never asset:

| id | type | name | purpose |
|---|---|---|---|
| 3234 | expense | `PayPal` | Generic destination when no merchant is recoverable from the bank line. |
| 3802 | expense | `PayPal Paga in 3` | Bucket for the user's PayPal BNPL splits. |
| 4337 | expense | `PayPal Fee` | PayPal system fees. |
| 4250 | expense | `Enrico (PayPal)` | A personal payee whose name keeps the PayPal hint. |
| 4413 | revenue | `PayPal Payout` | Source for incoming PayPal payouts to Fineco. |

Do not recreate the PayPal asset. Do not write rules whose action is `set_destination_account=PayPal` or `set_source_account=PayPal` expecting an asset to absorb the funds — those resolve to the expense bucket above, which is correct.

## 5. Revolut funding and the topup convention

Revolut is topped up by Fineco (debit *or* credit card via Apple Pay). In Firefly that's always a **transfer** between assets — `fineco → revolut` — not a withdrawal to an expense.

A previous bug recorded 31 topups as withdrawals to a `"Revolut"` expense account, deeply skewing the revolut asset balance. That's resolved: topups are now transfers, the residual expense was renamed to **`Revolut (misc P2P/Ramp)` (id=3237)** and holds 9 real outflows for Revolut Ramp crypto purchases and peer-to-peer transfers to individual people — those still need per-person re-categorisation manually.

Going forward, rule 21 (`[transfer] Revolut Top-Up (Fineco → Revolut)`) handles Fineco-sourced top-ups.

## 6. Account taxonomy

| Firefly type | Used for | Count today | Convention |
|---|---|---:|---|
| asset | Real money holders | 6 | One per bank wallet/card; multi-currency only if the wallet is actually used. |
| liability | Real debts | 1 | Currently only Findomestic. |
| revenue | Income sources | ~8 | Salary (Jakala), family transfers (Papà → Mediobanca), AECOM, Revolut Crypto sales, `PayPal Payout`, etc. |
| expense | Merchants | ~540 | One canonical entry per real-world merchant. Bank-statement-style descriptors and `PAYPAL *xxx` variants get merged into the canonical merchant, not kept as separate accounts. |
| cash | Firefly built-in "Cash account" | 1 | Reserved for *physical* cash (ATM withdrawals) and as Firefly's "unidentified counterparty" bucket. **Should be small.** If it grows, the importer or a rule is failing to attribute a real source — fix that, don't normalize Cash-as-merchant. |

Merchant naming conventions:
- Canonical merchants have short, human names: `Glovo`, `Amazon`, `A2A Energia`, `Trenitalia`, `ILIAD`, `Apple Services`, `Telepass`, `Decathlon`, `Affitto` (rent).
- Bank descriptions like `"DECATHLON ITALIA srl U Lissone IT"` or `"Glovo 19apr Lufp4yu1"` are *not* canonical — they're statement noise that should resolve into the canonical merchant via a rule.
- Personal payees keep readable names (e.g. `Marco Ninfa`, `Alessandro Siviero`, `Luca Faggio`). Avoid the `PAYPAL *` prefix on these — that prefix is statement noise, not part of the person's identity.

## 7. Categories (the 28 buckets)

```
affitto · applications · bar & restaurants · car · cash · cloud ·
commissioni · credito · crypto · delivery · drinks · events ·
internet · papà · pharma & docs · rimborsi · salute · satispay ·
shopping · spesa · sport · stipendi · tabacchi · taxi · transfer ·
transport · trasferimenti personali · utenze
```

Conventions:
- Italian for groceries (`spesa`), bills (`utenze`), rent (`affitto`), bank fees (`commissioni`), salary (`stipendi`).
- Internal transfers between own assets get category `transfer` (or `trasferimenti personali` for transfers involving external bridges like the PayPal Payout flow).
- `papà` is family income from the user's father.
- `rimborsi` is reimbursements.

## 8. Rules and bills

**Rule groups (23):** organized by purpose — `Merchants`, `Default rules`, `Income`, `Expense accounts`, `System`, `subscriptions`, `Categories` (catchall), `Revenues`, plus 15 merchant subgroups by category (Bar & Restaurants, Grocery, Shopping, Transport, Fuel, Utilities, Health, Sport, Events, Apps, Cloud, Tabacco, Drinks, Delivery, Credit).

**Bills (4 active):**
- `Rent` — quarterly MAV (Italian payment slip). Bank description starts `"MAV nr. 03069 …"`; rule 34 (`[sub] Rent (MAV)`) links it to the bill *and* sets `category=affitto`.
- `ILIAD` — monthly mobile.
- `GitHub Org` — monthly.
- `GitHub Copilot` — monthly. Triggered by `description_contains=Github`.

**System rules covering Revolut and PayPal passthroughs:**
- Rule 21 — `[transfer] Revolut Top-Up (Fineco → Revolut)` (Fineco-sourced top-ups become transfers, not withdrawals).
- Rule 428 — `[passthrough] PayPal SDD (no merchant) → expense:PayPal` (Fineco SDD with mandate `LU96ZZZ0000000000000000058`).
- Rule 429 — `[income] PayPal Payout (INSTANT TRANSFER / SEPA Estero)` (Deposit + `PayPal (Europe)` → revenue `PayPal Payout` + category `trasferimenti personali`).
- Rule 430 — `[crypto] Revolut Ramp → expense:Revolut Ramp + category:crypto`.
- Rule 431 — `[transfer] Revolut P2P (Inviato da Revolut) → category:trasferimenti personali` (no destination override — Firefly auto-creates a per-recipient expense from the description, which *is* the desired per-person split).

## 9. Hard invariants (don't violate these — or things break in subtle ways)

1. **Drift correction = `opening_balance` edit.** Never create reconciliation transactions, fake withdrawals/deposits, or `Cash account` plugs to align a balance. Adjust the asset's `opening_balance` field (see §2a). One mechanism, applied uniformly.
2. **Bank statement descriptions are not merchants.** The importer creates an expense account with the full description when no rule matches. Those auto-merchants are noise — every cleanup pass should fold them back into the canonical merchant.
3. **Don't trust the Carta Credito Fineco balance.** Imports are sporadic. Use it for categorisation history, not as ground truth.
4. **PayPal is not an asset, never was.** Don't recreate the PayPal asset account; don't treat PayPal as if it holds the user's money. PayPal-mediated transactions are either resolved into their real merchant (`Fineco → <Merchant>`) or, when the merchant is unrecoverable from the bank line, attributed to the `PayPal` expense bucket. Incoming PayPal payouts come from the `PayPal Payout` revenue.
5. **"Cash account" is for unidentified or physical cash, nothing else.** If `Cash account → fineco` deposits start accumulating, the importer or a rule isn't catching a real source — fix it upstream, don't normalize the Cash-as-source pattern.
6. **Merge before delete.** When pruning duplicate merchants, do the reassignment (variant tx → canonical) *before* deleting the variant. Otherwise the canonical (often `bal=0` and `last_activity=None`) gets caught by stale-cleanup filters.
7. **Apply rules sparingly on bulk mutations.** When editing transactions programmatically (PUT `/transactions/{id}`), set `apply_rules: false, fire_webhooks: false`. Otherwise a bulk fix triggers thousands of rule re-evaluations.

## 10. When to go to the operational skill

For anything that requires *acting* — calling the API, running artisan commands, rotating the importer config, querying the DB, triggering autoimport, applying rules in bulk — load the **`firefly` skill** (sibling at `.claude/skills/firefly/SKILL.md`). That skill has the surfaces and the helper scripts. This one tells you what your action should *mean*.

Always pair the two: read this skill to understand the user's model; read `firefly` to perform the work.
