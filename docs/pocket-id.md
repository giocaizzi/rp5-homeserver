# Pocket ID

Runbook for Pocket ID, the passkey-only OIDC provider used as a Cloudflare Access login method. Passkeys (stored in Bitwarden) log in to every Access-gated UI. Paths and settings: [services/pocket-id/README.md](../services/pocket-id/README.md).

## Overview

| Piece | Where |
|-------|-------|
| Stack `pocket-id`, service `pocket-id_app` (v2.19, port 1411) | `services/pocket-id/` |
| Data | volume `app_data` at `/app/data` |
| Encryption key | Swarm secret `pocket-id_encryption_key` -> `ENCRYPTION_KEY_FILE` (Secrets Manager key of the same name) |
| Public URL | `https://id.<domain>` through the tunnel |
| nginx route | `infra/nginx/conf.d/services/pocket-id.conf`, no Access JWT check |
| Access login method | `cloudflare_zero_trust_access_identity_provider.pocket_id` (generic OIDC, PKCE) in `cloud/` |
| Break-glass | dashboard-managed **One-time PIN** login method, stays enabled |
| Updates | Shepherd, tier core, floating `v2.19` tag (patch releases) |

Behavior:

- After bootstrap there is no Access app on `id.<domain>`: Cloudflare's servers call the token and JWKS endpoints, so the host cannot sit behind Access.
- Settings come from env (`UI_CONFIG_DISABLED=true`): signups disabled, own-account edit off (Access trusts the email claim), insecure callbacks off.
- Access policies match on email (`cloud/main.tf`): the Pocket ID user's email must be the one in the `<SVC>_USERS` lists.
- `allowed_idps` is not set: the Access login page offers both methods.
- Never rotate the token signing key to EdDSA. Access supports RS256/RS512/PS512/ES256/ES384/ES512; keep the default RS256.

## One-time setup

Order matters; each step keeps One-time PIN as a way in.

1. Zero Trust > Integrations > Identity providers: confirm One-time PIN is enabled and the owner email is in every `<SVC>_USERS` list.
2. Add Secrets Manager key `pocket-id_encryption_key` (`openssl rand -base64 32`, no trailing newline), then sync it (token injected from the keyring, see [AGENTS.md](../AGENTS.md)):
   ```bash
   PI_SSH_USER=pi ./scripts/create_secrets.sh pocket-id
   ```
3. Create the Portainer remote stack and the `WEBHOOK_ID_POCKET_ID` secret (environment `pi-services`) as in [services/pocket-id/README.md](../services/pocket-id/README.md).
4. Cloudflare zone setting: turn Rocket Loader off (it breaks Pocket ID's Content Security Policy).
5. Merge the stage 1 cloud PR (`feat(cloud): add the Pocket ID hostname behind a temporary Access gate`: DNS, tunnel ingress, owner-only Access app on `id.<domain>`) and the infra route PR, then cut the infra release.
6. Open `https://id.<domain>/setup` (Access asks for a One-time PIN). Create the admin with the policy email and add the passkey (Bitwarden). Setup works only until the first account exists.
7. Under My Account, enroll a second passkey on another authenticator (hardware key or platform keychain), so losing the vault does not lose Pocket ID.
8. Administration > User Groups: create group `access`, add the admin. OIDC Clients > add `Cloudflare Access`:
   - callback `https://<team>.cloudflareaccess.com/cdn-cgi/access/callback`
   - PKCE on
   - allowed groups `access`

   Copy client id and secret into Secrets Manager (record) and into the GitHub environment secrets (value from stdin, never on the command line or printed):
   ```bash
   gh secret set POCKET_ID_CLIENT_ID -e cloud-plan
   gh secret set POCKET_ID_CLIENT_ID -e cloud-production
   gh secret set POCKET_ID_CLIENT_SECRET -e cloud-plan
   gh secret set POCKET_ID_CLIENT_SECRET -e cloud-production
   ```
   Add the client id as a line in the `LEAK_PATTERNS` secret (repo and Dependabot).
9. Ensure the Terraform Cloudflare API token has the permission "Access: Organizations, Identity Providers, and Groups Write".
10. Mark the stage 2 PR ready (`feat(cloud): add Pocket ID as an Access login method`) and merge it. It removes the temporary Access app and adds the login method (URLs `https://id.<domain>/authorize`, `/api/oidc/token`, `/.well-known/jwks.json`); `apply-cloud` applies it.
11. Verify:
    - Zero Trust dashboard: Test button on the Pocket ID login method.
    - Log in to homepage, then backrest, then the rest, choosing Pocket ID. Check the `cf_access enforce` log lines as in [access-jwt.md](./access-jwt.md).
    - Prove the fallback: stop Pocket ID, log in to an app with One-time PIN, scale back.
      ```bash
      ssh pi@pi.local 'docker service scale pocket-id_app=0'
      ssh pi@pi.local 'docker service scale pocket-id_app=1'
      ```

## Day-to-day

| Task | How |
|------|-----|
| Add a passkey | My Account > add passkey on the new authenticator |
| Add a user | Administration > Users > create, then generate a Login Code (short lifetime) and hand it over. The user's email must be in the `<SVC>_USERS` lists and the user in group `access` |
| Change settings | Edit env in `services/pocket-id/docker-compose.yml`, PR, service release (UI settings are disabled) |

## Recovery

| Situation | Action |
|-----------|--------|
| Lost admin passkey | Generate a 1-hour login link on the Pi, open it, enroll a new passkey |
| Pocket ID or Pi down | Choose One-time PIN on the Access login page |

```bash
ssh pi@pi.local 'docker exec "$(docker ps -q -f label=com.docker.swarm.service.name=pocket-id_app | head -n1)" /app/pocket-id one-time-access-token <email>'
```

Restore from backup: [RUNBOOKS/restore-database.md](./RUNBOOKS/restore-database.md). The Backrest pre-snapshot hook dumps `pocket-id.zip` (`/app/pocket-id export --path -`, upstream: experimental) plus the raw volume. The encryption key from Secrets Manager is required to restore.

## Encryption key rotation

1. In the running task: `/app/pocket-id encryption-key-rotate --new-key <new key>`.
2. Docker secrets are immutable: bump the secret name suffix in the compose file and in Secrets Manager in the same change, run `create_secrets.sh pocket-id`, redeploy.

## Rollback

| Scope | Action |
|-------|--------|
| Fast | Choose One-time PIN at login |
| Durable | Revert the stage 2 PR (removes the login method); apps keep working with One-time PIN |
| Stack | Stop `pocket-id` at will; other apps are unaffected |

## Upgrades and security

Follow the pocket-id GitHub security advisories. Patch releases arrive through Shepherd on the `v2.19` tag; minor bumps by PR on the tag.
