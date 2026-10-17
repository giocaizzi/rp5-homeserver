/**
 * Worker environment bindings.
 *
 * `vars` (rendered from registry.json by render-config.sh) — per-service.
 * Secrets (wrangler secret put --env <svc>) — sensitive, per-service.
 * Bindings — KV namespace + the OAuthProvider helper injected by the library.
 */
import type { OAuthHelpers } from "@cloudflare/workers-oauth-provider";

export interface Env {
  // --- bindings ---
  OAUTH_KV: KVNamespace;
  /** Injected by @cloudflare/workers-oauth-provider into the default handler. */
  OAUTH_PROVIDER: OAuthHelpers;

  // --- vars (non-secret) ---
  SERVICE_NAME: string;
  /** Full upstream MCP endpoint, e.g. https://greenhouse.<domain>/mcp */
  UPSTREAM_URL: string;
  /** Authorization scheme for UPSTREAM_BEARER; defaults to "Bearer" (Langfuse: "Basic"). */
  UPSTREAM_AUTH_SCHEME?: string;
  /** Comma-separated groups allowed on this server (registry.json `allow`). */
  ALLOW_GROUPS: string;
  /** JSON {"<group>": ["<email>", ...]}; empty means every ALLOWED_EMAILS address is in `owner`. */
  MCP_GROUPS?: string;
  /** Comma-separated emails: the `owner` group while MCP_GROUPS is unset. */
  ALLOWED_EMAILS: string;

  // --- secrets ---
  GOOGLE_CLIENT_ID: string;
  GOOGLE_CLIENT_SECRET: string;
  /** App-level bearer the upstream MCP server validates (injected server-side). */
  UPSTREAM_BEARER: string;
  /** Optional JSON object of extra upstream headers, e.g. {"X-Portainer-API-Key":"ptr_…"}. */
  UPSTREAM_EXTRA_HEADERS?: string;
  /** Cloudflare Access service-token credentials to traverse CF Access to the origin. */
  CF_ACCESS_CLIENT_ID: string;
  CF_ACCESS_CLIENT_SECRET: string;
}

/** Props attached to the issued token; available as ctx.props in the API handler. */
export interface Props {
  email: string;
}
