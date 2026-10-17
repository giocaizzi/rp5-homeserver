/**
 * Default (non-API) handler: runs the user-login leg of the OAuth flow.
 *
 * Claude.ai hits /authorize on THIS Worker (which the library has registered as
 * the OAuth authorization server, same origin as the /mcp resource). Every client
 * first gets a consent page naming it and where its token will go; only after
 * Allow do we delegate the human login to Google, gate on the email allowlist,
 * then call completeAuthorization() to hand an auth code back to the client.
 * The library's consent/upstream helpers bind each step to the browser, so the
 * form can't be forged or framed and a stolen Google code can't be replayed.
 *
 * Routes:
 *   GET  /authorize  → validate redirect URI, render consent page
 *   POST /authorize  → Allow: redirect to Google; Deny: access_denied to the client
 *   GET  /callback   → verify Google identity + email, completeAuthorization
 */
import {
  AuthorizationError,
  CimdFetchError,
  authorizationErrorRedirect,
  type ConsentDescription,
} from "@cloudflare/workers-oauth-provider";
import type { Env } from "./env";
import { isAllowedEmail, isAllowedRedirect } from "./policy";

const GOOGLE_AUTH = "https://accounts.google.com/o/oauth2/v2/auth";
const GOOGLE_TOKEN = "https://oauth2.googleapis.com/token";
const GOOGLE_USERINFO = "https://openidconnect.googleapis.com/v1/userinfo";

const escape = (value: string) => value.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

function text(message: string, status: number): Response {
  return new Response(message, { status, headers: { "content-type": "text/plain; charset=utf-8" } });
}

function consentPage(service: string, d: ConsentDescription, handle: string): string {
  const name = escape(d.clientName);
  const origin = d.clientDomain
    ? `Published by <strong>${escape(d.clientDomain)}</strong>.`
    : "This app registered itself; its name is not verified.";
  const loopback = d.redirectIsLoopback
    ? "<p><strong>This sends access to an app on your computer.</strong> Continue only if you just started connecting from it.</p>"
    : "";
  return `<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Connect ${name} to ${escape(service)}</title>
<style>body{font:16px system-ui,sans-serif;max-width:32rem;margin:3rem auto;padding:0 1rem}button{font:inherit;padding:.5rem 1rem;margin-right:.5rem}</style>
<h1>Allow ${name} to use ${escape(service)}?</h1>
<p>${origin} Access will be sent to <strong>${escape(d.redirectHost)}</strong>.</p>
${loopback}
<p>You'll sign in with Google next.</p>
<form method="post">
  <input type="hidden" name="handle" value="${escape(handle)}">
  <button name="decision" value="approve">Allow</button><button name="decision" value="deny">Deny</button>
</form>`;
}

async function authorize(request: Request, env: Env): Promise<Response> {
  const oauth = env.OAUTH_PROVIDER;

  if (request.method === "POST") {
    const form = await request.formData();
    const handle = String(form.get("handle") ?? "");
    if (form.get("decision") !== "approve") {
      const denied = await oauth.denyConsent(request, handle);
      return new Response(null, { status: 302, headers: denied.headers });
    }
    const approved = await oauth.approveConsent(request, handle);
    const { state, headers } = await oauth.beginUpstream(approved.request, { headers: approved.headers });
    const g = new URL(GOOGLE_AUTH);
    g.searchParams.set("client_id", env.GOOGLE_CLIENT_ID);
    g.searchParams.set("redirect_uri", `${new URL(request.url).origin}/callback`);
    g.searchParams.set("response_type", "code");
    g.searchParams.set("scope", "openid email profile");
    g.searchParams.set("state", state);
    g.searchParams.set("prompt", "select_account");
    headers.set("Location", g.toString());
    return new Response(null, { status: 302, headers });
  }

  const authReq = await oauth.parseAuthRequest(request);
  // The client is validated by now, but its redirect URI may predate the registration
  // allowlist: never send a code anywhere else.
  if (!isAllowedRedirect(authReq.redirectUri)) {
    return text("This app's redirect address is not allowed for this connector.", 400);
  }
  const details = await oauth.describeConsent(authReq);
  const consent = await oauth.beginConsent(authReq);
  consent.headers.set("content-type", "text/html; charset=utf-8");
  return new Response(consentPage(env.SERVICE_NAME, details, consent.handle), { headers: consent.headers });
}

async function callback(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const { request: authReq, headers } = await env.OAUTH_PROVIDER.finishUpstream(request);
  const code = url.searchParams.get("code");
  if (url.searchParams.get("error") || !code) {
    headers.set("Location", authorizationErrorRedirect(authReq, "access_denied"));
    return new Response(null, { status: 302, headers });
  }

  // Exchange the Google code for tokens.
  const tokenResp = await fetch(GOOGLE_TOKEN, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: env.GOOGLE_CLIENT_ID,
      client_secret: env.GOOGLE_CLIENT_SECRET,
      redirect_uri: `${url.origin}/callback`,
      grant_type: "authorization_code",
    }),
  });
  if (!tokenResp.ok) return text("Google token exchange failed", 502);
  const tokens = (await tokenResp.json()) as { access_token?: string };
  if (!tokens.access_token) return text("Google did not return an access token", 502);

  const userResp = await fetch(GOOGLE_USERINFO, {
    headers: { authorization: `Bearer ${tokens.access_token}` },
  });
  if (!userResp.ok) return text("Google userinfo lookup failed", 502);
  const user = (await userResp.json()) as { email?: string; email_verified?: boolean };
  const email = (user.email ?? "").toLowerCase();

  if (!user.email_verified || !isAllowedEmail(env, email)) {
    return text(`Access denied for ${email || "this account"}.`, 403);
  }

  // Identity verified + allowlisted → issue the auth code back to the client.
  const { redirectTo } = await env.OAUTH_PROVIDER.completeAuthorization({
    request: authReq,
    userId: email,
    scope: authReq.scope,
    metadata: { label: email },
    props: { email },
  });
  headers.set("Location", redirectTo);
  return new Response(null, { status: 302, headers });
}

export const GoogleHandler = {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);
    try {
      if (pathname === "/authorize") return await authorize(request, env);
      if (pathname === "/callback" && request.method === "GET") return await callback(request, env);
    } catch (error) {
      // Redirect only to a validated client; render everything else here.
      if (error instanceof AuthorizationError && error.redirectTo) {
        return Response.redirect(error.redirectTo, 302);
      }
      if (error instanceof AuthorizationError) return text(error.description, 400);
      if (error instanceof CimdFetchError) return text("This app could not be verified.", 400);
      throw error;
    }
    return text("Not found", 404);
  },
};
