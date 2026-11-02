/**
 * Who may connect, and where tokens may be sent.
 *
 * - Group allowlist: an email may use this server if it belongs to one of the
 *   server's ALLOW_GROUPS (registry.json `allow`); membership comes from
 *   MCP_GROUPS, or ALLOWED_EMAILS as group `owner` while MCP_GROUPS is unset.
 *   Checked at login, on every token refresh and on every /mcp call, so removing
 *   an address (and redeploying) cuts it off at once instead of when its 30-day
 *   refresh token expires.
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
  "https://antigravity.google/oauth-callback",
  "https://cursor.com/api/mcp/oauth-callback",
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

const list = (csv: string | undefined) => (csv ?? "").split(",").map((s) => s.trim()).filter(Boolean);

function groups(env: Env): Record<string, string[]> {
  // render-config.sh validates the shape; a bad value throws, which fails closed.
  if (env.MCP_GROUPS) return JSON.parse(env.MCP_GROUPS) as Record<string, string[]>;
  return { owner: list(env.ALLOWED_EMAILS) };
}

export function isAllowedEmail(env: Env, email: string | undefined): boolean {
  if (!email) return false;
  const target = email.toLowerCase();
  const members = groups(env);
  return list(env.ALLOW_GROUPS).some((g) =>
    Object.hasOwn(members, g) && members[g].some((e) => e.trim().toLowerCase() === target),
  );
}
