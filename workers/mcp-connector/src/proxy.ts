/**
 * API handler: invoked by the OAuth library ONLY after a valid access token is
 * presented on the apiRoute (/mcp). It reverse-proxies the MCP request to the
 * self-hosted upstream, swapping Claude's bearer for the credentials the origin
 * expects:
 *   - CF-Access-Client-Id / CF-Access-Client-Secret  → traverse Cloudflare Access
 *   - Authorization: Bearer <app token>               → satisfy the MCP server
 *
 * The upstream origin (Pi via tunnel) is never reachable without these, so it is
 * never exposed unauthenticated. The streamed response (JSON or SSE) is piped back
 * verbatim so the streamable-HTTP MCP transport works end to end.
 */
import type { Env, Props } from "./env";

// Hop-by-hop / connection headers that must not be forwarded.
const STRIP_REQUEST_HEADERS = [
  "authorization",
  "cf-access-client-id",
  "cf-access-client-secret",
  "host",
  "cf-connecting-ip",
  "cf-ray",
  "x-forwarded-host",
  "x-forwarded-proto",
];

export const proxyHandler = {
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext & { props?: Props },
  ): Promise<Response> {
    const inUrl = new URL(request.url);
    // UPSTREAM_URL already carries the full path (e.g. .../mcp); preserve query string.
    const target = env.UPSTREAM_URL + inUrl.search;

    const headers = new Headers(request.headers);
    for (const h of STRIP_REQUEST_HEADERS) headers.delete(h);
    headers.set("authorization", `Bearer ${env.UPSTREAM_BEARER}`);
    headers.set("cf-access-client-id", env.CF_ACCESS_CLIENT_ID);
    headers.set("cf-access-client-secret", env.CF_ACCESS_CLIENT_SECRET);
    // Trace which authenticated user drove the call (best-effort).
    if (ctx.props?.email) headers.set("x-mcp-connector-user", ctx.props.email);

    const init: RequestInit = {
      method: request.method,
      headers,
      redirect: "manual",
    };
    if (request.method !== "GET" && request.method !== "HEAD") {
      init.body = request.body;
      // Required by the Workers runtime when streaming a request body.
      (init as RequestInit & { duplex: string }).duplex = "half";
    }

    const upstream = await fetch(target, init);

    // Stream the response back unchanged (supports SSE / chunked MCP responses).
    const outHeaders = new Headers(upstream.headers);
    outHeaders.delete("transfer-encoding");
    return new Response(upstream.body, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers: outHeaders,
    });
  },
};
