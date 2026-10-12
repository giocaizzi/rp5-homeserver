# Releases & Versioning

Automated versioning, changelogs, and tags via [release-please](https://github.com/googleapis/release-please). This is the diagram-led companion to the **[Pull requests & commit titles](../AGENTS.md#pull-requests--commit-titles--mandatory-format)** rules in `AGENTS.md` (the authoritative, imperative contract). Read them together.

release-please cuts versions, changelogs, and tags. **The runtime deploys are release-gated off those tags** — merging a feature PR *stages* a change; merging the Release PR *ships* it. The one exception is `cloud/` Terraform, which stays plan-reviewed-on-merge (see [Deployment](#deployment-release-gated)).

## Workflows

| Workflow | File | Trigger | Role |
|---|---|---|---|
| **release-please** | `release-please.yml` | push to `main` | Parses Conventional Commits, maintains one batched Release PR; merging it bumps versions + `CHANGELOG.md` and publishes per-component tags + GitHub Releases. |
| **PR title** | `pr-title.yml` | PR opened/edited/reopened/synced | Validates the PR title is a Conventional Commit with a mandatory scope. Skips `release-please--*` PRs. |
| **Deploy infra** | `deploy-infra.yml` | **`infra` release** (`v*`) + manual | Self-hosted Pi runner runs `sync_infra.sh --local`. |
| **Deploy services** | `deploy-services.yml` | **service release** (`<stack>-v*`) + manual | Parses the stack from the tag, POSTs its Portainer webhook on the Pi. |
| **Deploy workers** | `deploy-workers.yml` | **`mcp-connector` release** (`mcp-connector-v*`) + manual | GitHub-hosted runner: `wrangler deploy --env` for each Worker env. |
| **Apply cloud** | `apply-cloud.yml` | push `main` ∩ `cloud/**` | `terraform apply` — plan-reviewed-on-merge, **not** release-gated. |

```mermaid
flowchart LR
    Commit["Conventional Commits<br/>merged to main"] --> RP["release-please.yml"]
    RP --> PR["one batched Release PR<br/>chore(repo): release main"]
    PR -->|merge| Cut["per-component:<br/>version bump + CHANGELOG<br/>+ tag + GitHub Release"]
    Cut --> Infra["infra → vX.Y.Z<br/>(writes infra/VERSION)"]
    Cut --> Comp["service → service-v0.Y.Z"]
    Infra -->|"release event"| DI["deploy-infra.yml<br/>sync_infra --local (Pi)"]
    Comp -->|"release event"| DS["deploy-services.yml<br/>Portainer webhook (Pi)"]
```

## Components

Manifest mode: [`release-please-config.json`](../release-please-config.json) + [`.release-please-manifest.json`](../.release-please-manifest.json) (the version source of truth — **never hand-edit** it or the generated `CHANGELOG.md` files). A commit affects a component only when it touches files under that component's path.

| Component | Path | release-type | Tag | Version source |
|---|---|---|---|---|
| *(infra)* | `infra` | `simple` | `vX.Y.Z` | `infra/VERSION` (via `version-file`) |
| `cloud` | `cloud` | `simple` | `cloud-vX.Y.Z` | manifest-only |
| `mcp-connector` | `workers/mcp-connector` | `node` | `mcp-connector-vX.Y.Z` | `package.json` |
| `<service>` | `services/<service>` | `simple` | `<service>-vX.Y.Z` | manifest-only |

Services covered: `adguard`, `ai`, `calibre`, `code`, `crm`, `firefly`, `greenhouse`, `langfuse`, `n8n`, `ntfy`, `observability`, `openclaw`. Stacks with repo bind mounts (`firefly`, `langfuse`, `observability`) also list `docker-compose.yml` under `extra-files`, so release-please bumps their `com.giocaizzi.config-rev` label and every release rolls the tasks.

Cross-cutting changes (CI, root docs, `scripts/`) use the `repo` scope, touch no component path, and cut **no** release.

## Deployment (release-gated)

The runtime stacks deploy **when their release is published**, not on merge to `main`:

| Target | Deployed by | Fires on | How |
|---|---|---|---|
| `infra/` stack | `deploy-infra.yml` | `infra` release (bare `v*` tag) | self-hosted Pi runner → `sync_infra.sh --local` |
| `services/<stack>` | `deploy-services.yml` | service release (`<stack>-v*` tag) | Pi runner → that stack's Portainer webhook (local, bypasses CF WAF) |
| `workers/mcp-connector` | `deploy-workers.yml` | `mcp-connector` release (`mcp-connector-v*` tag) | GitHub-hosted runner → `npm ci`, typecheck, `wrangler deploy --env` per env (env `cloudflare-workers`) |
| `cloud/` Terraform | `apply-cloud.yml` | **push** `main` ∩ `cloud/**` | `terraform apply` (plan-reviewed-on-merge — **not** release-gated) |

- The deploy workflows trigger on `release: [published]`. Because release-please authors the release with the **GitHub App** token (not `GITHUB_TOKEN`), the `release` event *does* fire downstream workflows.
- A batched Release PR publishes **one release per changed component**, so each fires its own deploy; `deploy-services.yml` parses the stack from the tag and no-ops on non-service releases (`infra`, `cloud`, `mcp-connector`); `mcp-connector` is deployed by `deploy-workers.yml`.
- The release event checks out the **tagged commit**, so the deployed stack matches the released version. `sync_infra.sh` deploys in place and hot-reloads nginx (`nginx -t` + `nginx -s reload`) when files under `infra/nginx/` changed.
- Both Pi deploys also accept **`workflow_dispatch`** for manual runs (infra: `pull`/`restart`; services: a single `stack`).
- **Why `cloud/` is excluded:** Terraform is desired-state — release-gating it would let `main` diverge from applied infra until a release is cut. Its review gate is the plan (`ci.yml`), and merge applies it. release-please still versions `cloud` (`cloud-vX.Y.Z`) for the changelog/tag record.

## Versioning policy

- **`infra` is the one mature line** (`vX.Y.Z`, seeded `1.13.0`), the only component past `1.0.0`. Normal SemVer applies: `feat`→minor, `fix`/`perf`/`refactor`→patch, `feat!`/`BREAKING CHANGE:`→major.
- **Every other component is a `0.x` config track.** `bump-minor-pre-major: true` means a breaking change bumps **minor** while below `1.0.0` — nothing auto-graduates. Their **namespaced** tags (`greenhouse-v0.3.0`, …) keep them distinct from the vendored app's own version (e.g. Greenhouse `v3.x`, Grafana `11.x`): anything `0.x` is *this repo's config revision*, anything higher is the *upstream app*.
- **Graduate deliberately:** add a `Release-As: 1.0.0` footer to a commit scoped to that component's path. There is no automatic `1.0.0`.

> release-please is **SemVer-only** — CalVer/date-based versions aren't supported. The `0.x` namespacing above is the chosen way to avoid confusion with upstream versions.

### `infra/VERSION` is release-managed

`infra/VERSION` is the `infra` component's `version-file`: release-please rewrites it in place (kept as a bare `X.Y.Z` string, so `homepage` and `sync_infra.sh` read it unchanged). Because the `infra` release fires `deploy-infra.yml`, **cutting an `infra` release implies an in-place infra deploy via [`sync_infra.sh`](../scripts/sync_infra.sh).** To change `infra/**` *without* a deploy, use a non-releasing type (`chore(infra):` / `docs(infra):`).

## Commit contract → bump

| Type | Bump (`infra`, ≥1.0) | Bump (`0.x` tracks) | CHANGELOG section |
|---|---|---|---|
| `feat` | minor | minor | Features |
| `fix` | patch | patch | Bug Fixes |
| `perf` | patch | patch | Performance Improvements |
| `refactor` | patch | patch | Code Refactoring |
| `revert` | patch | patch | Reverts |
| `docs` | none | none | Documentation |
| `feat!` / `BREAKING CHANGE:` | **major** | minor | (under its type) |
| `style` · `test` · `build` · `ci` · `chore` | none | none | hidden |

Enforcement is three layers: **`pr-title.yml`** (CI gate on the title), the **`conventional-commit-guard.sh`** PreToolUse hook (local, per-developer via gitignored `.claude/settings.local.json` — blocks malformed agent commits), and **squash-merge with title = PR title**, which makes the validated title the commit release-please parses.

## Required GitHub configuration

Deploys are keyless (WIF) / Portainer; the only release-automation secrets are the **GitHub App** credentials:

| Secret | Used by | Purpose |
|---|---|---|
| `RELEASE_PLEASE_APP_ID` | `release-please.yml` (`actions/create-github-app-token@v2`) | Numeric App ID of the release-please GitHub App. |
| `RELEASE_PLEASE_APP_PRIVATE_KEY` | same | The App's `.pem`. Mints a short-lived installation token so the Release PR is **not** authored by `GITHUB_TOKEN`. |

**Why the App:** `main` requires the `check` status check, and a PR opened by `GITHUB_TOKEN` does **not** trigger `on: pull_request` CI — so `check` would never report and the Release PR could never merge. An App-authored PR triggers CI normally. App repo permissions: **Contents: R/W** + **Pull requests: R/W**, installed on this repo.

**Branch protection (`main`):** require both `check` (from `ci.yml`) and `Validate PR title` (from `pr-title.yml`); squash-only merge with commit title = PR title.

## First run — clean slate

`bootstrap-sha` in the config pins the adoption commit, so the first Release PR contains only commits landed **after** release-please was adopted — earlier history is not back-filled. Once that first Release PR merges, `bootstrap-sha` is ignored and can be removed.

## Pull requests & commit titles (mandatory format)

**Every PR title and every commit subject MUST be `type(scope): description`** — a [Conventional Commit](https://www.conventionalcommits.org) **with a mandatory scope**. This is not optional. `main` is **squash-only** with `squash_merge_commit_title=PR_TITLE`, so **the PR title becomes the commit subject release-please parses on `main`**. A malformed or unscoped title silently misattributes — or drops — the release.

- **`type`** ∈ `feat` · `fix` · `perf` · `refactor` · `revert` · `docs` · `style` · `test` · `build` · `ci` · `chore`. The type drives the bump: `feat` → MINOR, `fix`/`perf`/`refactor`/`revert` → PATCH, `feat!` or a `BREAKING CHANGE:` footer → MAJOR; `docs`/`style`/`test`/`build`/`ci`/`chore` → no bump.
- **`scope`** (REQUIRED) — any lowercase token (`[a-z][a-z0-9-]*`); **not an allowlist** (release-please attributes releases by file **path**, not scope, so the scope is advisory). Pick it to communicate *what changed*:
  - a **release-please component** when the PR touches that path — `infra` (the **main `vX.Y.Z` line**, `infra/VERSION`), `cloud`, `mcp-connector` (`workers/`), or a service (`greenhouse`, `n8n`, …). Keep each PR to a **single** component so the version + changelog land on the right one.
  - a **meta scope** for cross-cutting work that touches no component → no release: `cicd` (`.github/workflows/**`, deploy scripts), `repo` (root docs, `scripts/`, tooling), `deps` (dependency bumps), etc.
- **`description`** — imperative, lowercase first word, no trailing period.
- Breaking change: add `!` after the scope (`feat(greenhouse)!: …`) and/or a `BREAKING CHANGE:` footer.

Examples: `feat(greenhouse): add humidity sensor` · `fix(infra): correct nginx healthcheck` · `ci(repo): add pr-title lint` · `chore(openclaw)!: drop legacy auth`.

Enforced on **three** layers: the **`pr-title.yml`** workflow (a plain regex — no third-party action) validates every PR title; the **`conventional-commit-guard.sh`** `PreToolUse` hook (wired per-developer in the gitignored `.claude/settings.local.json`) blocks any agent commit whose subject doesn't match; and the squash-merge setting makes the validated PR title the commit of record. release-please's own Release PRs (branch `release-please--*`, titled `chore(repo): release …`) are already compliant and additionally skipped by the lint as a safety net.

### Releases (release-please)

`release-please.yml` watches `main`, parses these commits, and maintains **one batched Release PR** (`release-please-config.json` + `.release-please-manifest.json`); merging it bumps each changed component's version + `CHANGELOG.md` and publishes the tag(s) — `vX.Y.Z` for `infra` (which writes `infra/VERSION`), `<component>-v0.x` for the `0.x` config tracks (`cloud`, `mcp-connector`, the services). **The runtime deploys are release-gated off those tags:** the `infra` release fires `deploy-infra.yml`, a service release fires `deploy-services.yml` (`cloud/` Terraform stays apply-on-merge via `apply-cloud.yml`). So merging a feature PR *stages* a change; merging the Release PR *ships* it. release-please authenticates via a **GitHub App** (`RELEASE_PLEASE_APP_ID` + `RELEASE_PLEASE_APP_PRIVATE_KEY`) so its Release PR triggers the required `check` check — and so the published `release` events trigger the deploy workflows.

**Full flow, components, versioning policy, and required GitHub config: this document.** Never hand-edit `.release-please-manifest.json`, `infra/VERSION`, or any generated `CHANGELOG.md`.
