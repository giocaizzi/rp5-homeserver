/**
 * Default (non-API) handler: runs the user-login leg of the OAuth flow.
 *
 * Claude.ai hits /authorize on THIS Worker (which the library has registered as
 * the OAuth authorization server, same origin as the /mcp resource). We delegate
 * the actual human login to Google, gate on an email allowlist, then call
 * completeAuthorization() to hand an auth code back to Claude.
 *
 * Routes:
 *   GET /authorize  → stash Claude's auth request, redirect to Google
 *   GET /callback   → verify Google identity + email, completeAuthorization
 */
import type { Env, AuthRequest } from "./env";

const GOOGLE_AUTH = "https://accounts.google.com/o/oauth2/v2/auth";
const GOOGLE_TOKEN = "https://oauth2.googleapis.com/token";
const GOOGLE_USERINFO = "https://openidconnect.googleapis.com/v1/userinfo";

export const GoogleHandler = {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/authorize") {
      const authReq = await env.OAUTH_PROVIDER.parseAuthRequest(request);
      // Stash Claude's authorize request server-side; round-trip a nonce via Google `state`.
      const nonce = crypto.randomUUID();
      await env.OAUTH_KV.put(`login:${nonce}`, JSON.stringify(authReq), {
        expirationTtl: 600,
      });

      const g = new URL(GOOGLE_AUTH);
      g.searchParams.set("client_id", env.GOOGLE_CLIENT_ID);
      g.searchParams.set("redirect_uri", `${url.origin}/callback`);
      g.searchParams.set("response_type", "code");
      g.searchParams.set("scope", "openid email profile");
      g.searchParams.set("state", nonce);
      g.searchParams.set("prompt", "select_account");
      return Response.redirect(g.toString(), 302);
    }

    if (url.pathname === "/callback") {
      const code = url.searchParams.get("code");
      const nonce = url.searchParams.get("state");
      if (!code || !nonce) {
        return new Response("Missing code or state", { status: 400 });
      }

      const stored = await env.OAUTH_KV.get(`login:${nonce}`);
      if (!stored) {
        return new Response("Login session expired, retry the connection", { status: 400 });
      }
      await env.OAUTH_KV.delete(`login:${nonce}`);
      const authReq = JSON.parse(stored) as AuthRequest;

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
      if (!tokenResp.ok) {
        return new Response("Google token exchange failed", { status: 502 });
      }
      const tokens = (await tokenResp.json()) as { access_token?: string };
      if (!tokens.access_token) {
        return new Response("Google did not return an access token", { status: 502 });
      }

      const userResp = await fetch(GOOGLE_USERINFO, {
        headers: { authorization: `Bearer ${tokens.access_token}` },
      });
      if (!userResp.ok) {
        return new Response("Google userinfo lookup failed", { status: 502 });
      }
      const user = (await userResp.json()) as { email?: string; email_verified?: boolean };
      const email = (user.email ?? "").toLowerCase();
      const allowed = env.ALLOWED_EMAILS.split(",")
        .map((e) => e.trim().toLowerCase())
        .filter(Boolean);

      if (!user.email_verified || !allowed.includes(email)) {
        return new Response(`Access denied for ${email || "this account"}.`, { status: 403 });
      }

      // Identity verified + allowlisted → issue the auth code back to Claude.
      const { redirectTo } = await env.OAUTH_PROVIDER.completeAuthorization({
        request: authReq,
        userId: email,
        scope: authReq.scope,
        metadata: { label: email },
        props: { email },
      });
      return Response.redirect(redirectTo, 302);
    }

    return new Response("Not found", { status: 404 });
  },
};
