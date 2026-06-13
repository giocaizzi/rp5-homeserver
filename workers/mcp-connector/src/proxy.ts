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

// Forward ONLY the headers the MCP streamable-HTTP transport needs. The inbound
// request from Claude.ai carries a large browser/SDK header set (User-Agent,
// sec-*, x-stainless-*, tracing, etc.); blindly proxying that to a
// Cloudflare-proxied origin trips WAF managed rules ("Your request was
// blocked", 403). An allowlist keeps the subrequest clean and predictable.
const FORWARD_REQUEST_HEADERS = [
  "content-type",
  "accept",
  "mcp-session-id",
  "mcp-protocol-version",
  "last-event-id",
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

    const headers = new Headers();
    for (const h of FORWARD_REQUEST_HEADERS) {
      const v = request.headers.get(h);
      if (v) headers.set(h, v);
    }
    headers.set("authorization", `Bearer ${env.UPSTREAM_BEARER}`);
    headers.set("cf-access-client-id", env.CF_ACCESS_CLIENT_ID);
    headers.set("cf-access-client-secret", env.CF_ACCESS_CLIENT_SECRET);
    // Stable, benign User-Agent so the origin's WAF sees a predictable client.
    headers.set("user-agent", "mcp-connector/1.0 (+cloudflare-workers)");
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

    // Surface non-2xx upstream responses in `wrangler tail` (status + type only,
    // never the body — it may carry data). Enough to tell apart an origin WAF
    // block (403 text/plain), a bad bearer (401), and an app error.
    if (!upstream.ok) {
      console.warn(
        `[proxy] ${env.SERVICE_NAME} upstream ${upstream.status} ` +
          `(${request.method} ${inUrl.pathname}) ct=${upstream.headers.get("content-type")}`,
      );
    }

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
