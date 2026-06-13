/**
 * Worker environment bindings.
 *
 * `vars` (wrangler.jsonc) — non-secret, per-service.
 * Secrets (wrangler secret put --env <svc>) — sensitive, per-service.
 * Bindings — KV namespace + the OAuthProvider helper injected by the library.
 */
export interface Env {
  // --- bindings ---
  OAUTH_KV: KVNamespace;
  /** Injected by @cloudflare/workers-oauth-provider into the default handler. */
  OAUTH_PROVIDER: {
    parseAuthRequest(request: Request): Promise<AuthRequest>;
    completeAuthorization(opts: {
      request: AuthRequest;
      userId: string;
      scope: string[];
      props: Record<string, unknown>;
      metadata?: Record<string, unknown>;
    }): Promise<{ redirectTo: string }>;
  };

  // --- vars (non-secret) ---
  SERVICE_NAME: string;
  /** Full upstream MCP endpoint, e.g. https://greenhouse.giocaizzi.xyz/mcp */
  UPSTREAM_URL: string;
  /** Comma-separated email allowlist that may complete the OAuth login. */
  ALLOWED_EMAILS: string;

  // --- secrets ---
  GOOGLE_CLIENT_ID: string;
  GOOGLE_CLIENT_SECRET: string;
  /** App-level bearer the upstream MCP server validates (injected server-side). */
  UPSTREAM_BEARER: string;
  /** Cloudflare Access service-token credentials to traverse CF Access to the origin. */
  CF_ACCESS_CLIENT_ID: string;
  CF_ACCESS_CLIENT_SECRET: string;
}

/** Shape returned by OAUTH_PROVIDER.parseAuthRequest (subset we use). */
export interface AuthRequest {
  responseType: string;
  clientId: string;
  redirectUri: string;
  scope: string[];
  state: string;
  codeChallenge?: string;
  codeChallengeMethod?: string;
}

/** Props attached to the issued token; available as ctx.props in the API handler. */
export interface Props {
  email: string;
}
