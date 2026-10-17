/**
 * Who may connect, and where tokens may be sent.
 *
 * - Email allowlist: checked at login, on every token refresh and on every /mcp
 *   call, so removing an address (and redeploying) cuts it off at once instead of
 *   when its 30-day refresh token expires.
 * - Redirect URI allowlist: DCR is open, so without it anyone can register a client
 *   that redirects to their own site and phish an owner into a one-click grant
 *   (the confused-deputy problem). Only Claude's and VS Code's web callbacks and
 *   loopback (CLI) callbacks are accepted; the consent page warns on loopback.
 */
import type { Env } from "./env";

const WEB_CALLBACKS = new Set([
  "https://claude.ai/api/mcp/auth_callback",
  "https://claude.com/api/mcp/auth_callback",
  "https://vscode.dev/redirect",
]);

const LOOPBACK_HOSTS = new Set(["localhost", "127.0.0.1", "[::1]"]);

export function isAllowedRedirect(uri: string): boolean {
  if (WEB_CALLBACKS.has(uri)) return true;
  let u: URL;
  try {
    u = new URL(uri);
  } catch {
    return false;
  }
  return (u.protocol === "http:" || u.protocol === "https:") && LOOPBACK_HOSTS.has(u.hostname);
}

export function isAllowedEmail(env: Env, email: string | undefined): boolean {
  if (!email) return false;
  return env.ALLOWED_EMAILS.split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean)
    .includes(email.toLowerCase());
}
