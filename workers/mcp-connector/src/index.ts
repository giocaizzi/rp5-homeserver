/**
 * Single-origin OAuth + MCP reverse-proxy for Claude.ai custom connectors.
 *
 * The library makes THIS Worker both the OAuth 2.1 authorization server AND the
 * MCP resource on one origin — the topology Claude.ai's web/Desktop connector
 * handles, and the thing the failed Cloudflare Access "MCP portal" did not provide
 * (its authorization server lived on a separate *.cloudflareaccess.com host).
 *
 *   - /.well-known/oauth-authorization-server + /.well-known/oauth-protected-resource
 *     and /authorize, /token, /register are served by the library.
 *   - /authorize delegates human login to Google (defaultHandler), gated by email.
 *   - /mcp is token-protected and reverse-proxied to the self-hosted upstream.
 */
import OAuthProvider, { GrantType, OAuthError } from "@cloudflare/workers-oauth-provider";
import type { Env, Props } from "./env";
import { GoogleHandler } from "./google-handler";
import { isAllowedEmail, isAllowedRedirect } from "./policy";
import { proxyHandler } from "./proxy";

// 1.x needs the canonical resource (every token's audience) at construction.
// One codebase serves several envs on distinct workers.dev hosts, so build the
// provider per origin. `${origin}/mcp` is what 0.x advertised, hence what the
// existing grants carry: changing it signs every user out (#254).
const providers = new Map<string, OAuthProvider<Env>>();

function providerFor(origin: string): OAuthProvider<Env> {
  let p = providers.get(origin);
  if (!p) {
    p = new OAuthProvider<Env>({
      apiRoute: "/mcp",
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      apiHandler: proxyHandler as any,
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      defaultHandler: GoogleHandler as any,
      authorizeEndpoint: "/authorize",
      tokenEndpoint: "/token",
      // Claude.ai self-registers via Dynamic Client Registration (RFC 7591).
      clientRegistrationEndpoint: "/register",
      // DCR stays open (Claude.ai needs it), but a client may only name redirect URIs
      // we'd send a token to (policy.ts).
      clientRegistrationCallback: ({ clientMetadata }) => {
        const uris = clientMetadata.redirect_uris;
        if (!Array.isArray(uris) || uris.length === 0 || !uris.every((u) => typeof u === "string" && isAllowedRedirect(u))) {
          return { description: "redirect_uris must be Claude, VS Code, Antigravity or loopback callbacks" };
        }
      },
      // A refresh re-checks the allowlist, so a removed address loses access within
      // one access-token lifetime even if it never calls /mcp again.
      tokenExchangeCallback: ({ grantType, props, env }) => {
        if (grantType === GrantType.REFRESH_TOKEN && !isAllowedEmail(env, (props as Props).email)) {
          throw new OAuthError("invalid_grant", { description: "Access was revoked" });
        }
      },
      resourceMetadata: {
        resource: `${origin}/mcp`,
        authorization_servers: [origin],
      },
    });
    providers.set(origin, p);
  }
  return p;
}

export default {
  fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return providerFor(new URL(request.url).origin).fetch(request, env, ctx);
  },
};
