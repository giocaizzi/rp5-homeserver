# MCP edge: modular exposure, identity and ACLs (WIP)

Design for exposing self-hosted MCP servers to claude.ai and to local CLIs from one
place, with per-user identity, per-connector and per-tool ACLs, and selective sharing.
Tracker: #261. Status: Phase 0 in progress; Phase 1 done without the single deployment (#395); Phases 2–4 are proposals.

## Where we are

- `workers/mcp-connector`: one codebase, one Worker deployment **per upstream**
  (greenhouse, firefly, n8n, grafana, netdata, portainer, langfuse), generated from
  `registry.json` (upstream, auth scheme, mode, allowed groups). Google OAuth, then
  a group check per connector (membership from the `MCP_GROUPS` deploy secret), then
  a reverse proxy that swaps Claude's token for the upstream bearer and a CF Access
  service token, with one audit log line per call. Every caller becomes the same
  upstream identity.
- Twenty CRM (`services/crm`) bypasses the Worker: claude.ai talks to Twenty's own
  OAuth so each user keeps ownership. Access is bypassed for Anthropic's egress range
  `160.79.104.0/21`, which every claude.ai user shares: it narrows who can connect but
  does not identify anyone; Twenty's OAuth is the gate. Local CLIs can't reach it.
- Stdio-only servers (e.g. fli) have no path to claude.ai.

## Target

```
claude.ai / CLIs ──OAuth──► MCP edge Worker (one deployment, registry-driven)
                              ├─ identity: Google → email → groups
                              ├─ ACL: server allow-groups + tool allow/deny
                              ├─ identity propagation (mode per server)
                              └─ audit: user, server, tool
                                   │
                    CF Access (service token) ──► nginx (Access JWT check) ──► upstream
                                                       └─ stdio servers: supergateway stack
```

Registry target shape (Phase 1 ships `workers/mcp-connector/registry.json` with `shared` mode only; group membership stays out of the repo, in the `MCP_GROUPS` secret):

```yaml
groups:  { owner: [...], friends: [...] }
servers:
  fli:        { upstream: https://mcp-stdio.<domain>/fli/mcp, mode: shared, allow: [owner, friends] }
  portainer:  { upstream: ..., mode: shared, allow: [owner], tools: { allow: [read-only list] } }
  greenhouse: { upstream: ..., mode: signed-identity, allow: [owner] }
  firefly:    { upstream: ..., mode: per-user-credential, allow: [owner] }
  crm:        { mode: native-oauth }
```

Identity propagation modes:

| Mode | When | Edge behaviour |
|---|---|---|
| `shared` | Upstream has no users (fli, netdata, grafana read-only) | One service bearer + `X-MCP-User` for audit |
| `signed-identity` | Apps we own (greenhouse) | Short-lived JWT with email and groups; the app enforces ownership |
| `per-user-credential` | App has users and API keys, no OAuth (Firefly) | Per-user key from encrypted KV, by email |
| `native-oauth` | App has its own OAuth (Twenty) | Not proxied; claude.ai talks to the app |

Tool ACLs: the 2026-07-28 spec puts `Mcp-Method`/`Mcp-Name` on every request, so a
`tools/call` deny is a header check; hiding tools needs `tools/list` filtering.

Stdio servers: `services/mcp-stdio` with supergateway (arm64 image, `--config` with one
path, `apiKey` and `tools` filter per server, one process per session). Chosen over
sparfenyuk/mcp-proxy (no auth, no tool filter, shared process) and TBXark/mcp-proxy
(lighter, less active). A gateway with a UI and database (MetaMCP, mcphub, ContextForge,
agentgateway) adds an IdP/DB to run on the Pi for features the Worker already covers;
revisit mcphub only if friends need their own credentials on a shared server.

## Security review (2026-10-17)

| # | Finding | Severity | Status |
|---|---|---|---|
| 1 | Open DCR + no consent → one-click token theft (confused deputy) | High | Fixed in #388 |
| 2 | Portainer connector carries a full-access token (root on the Pi) | High | #392 |
| 3 | nginx doesn't validate the Access JWT; direct-to-origin traffic skips Access | Medium | #393 |
| 4 | Allowlist removal didn't revoke existing grants | Medium | Fixed in #388 |
| 5 | Calibre reader paths public, Basic auth only, Kobo token in URL | Medium | #394 |
| 6 | CRM bypass trusts the whole claude.ai egress range | Medium | Accepted (see above) |
| 7 | `otel.<domain>` outside `/v1/` reached Alloy without Access (verified: 401 from Alloy) | Low | #389, #391 |
| 8 | Path variants vs path-scoped Access apps | Low | Not vulnerable: `//mcp`, `/%6Dcp`, `/MCP`, `/x/../mcp` all stopped by Access |
| 9 | Stale grafana nginx comment | Low | #389 |
| 10 | Token-holding sidecar on `:latest` with Shepherd auto-pull | Low | #390 (grafana); portainer-mcp is already pinned |
| 11 | One global allowlist and Google client for all connectors | Low | Allowlist: per-connector groups (#395); Google client: Phase 4 |

## Phases

0. Security fixes above.
1. #395 config-driven edge: registry, per-connector ACLs, audit log. Done, keeping one
   deployment per server on workers.dev so existing connectors keep working; one
   deployment on custom domains is deferred (a URL change means re-adding every
   connector in claude.ai).
2. #396 `signed-identity`, `per-user-credential`, tool ACLs.
3. #397 stdio stack with fli first.
4. #398 sharing: groups, published Google client, rate limits.

## Open questions

- CIMD in `workers-oauth-provider` (`clientIdMetadataDocumentEnabled`): would let the
  redirect check rely on Claude's published client metadata instead of a URI list.
- Cloudflare Workers VPC: reaching the Pi through the tunnel with no public MCP
  hostnames would remove findings 3, 7 and 8 for MCP. Availability not checked.
- Alternative edge: agentgateway on the Pi (per-tool CEL policies, needs a separate IdP).
