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
import OAuthProvider from "@cloudflare/workers-oauth-provider";
import { GoogleHandler } from "./google-handler";
import { proxyHandler } from "./proxy";

export default new OAuthProvider({
  apiRoute: "/mcp",
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  apiHandler: proxyHandler as any,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  defaultHandler: GoogleHandler as any,
  authorizeEndpoint: "/authorize",
  tokenEndpoint: "/token",
  // Claude.ai self-registers via Dynamic Client Registration (RFC 7591).
  clientRegistrationEndpoint: "/register",
});
