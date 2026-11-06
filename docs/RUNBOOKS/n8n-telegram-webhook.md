# n8n Telegram webhook through Access

**When:** an n8n workflow uses a Telegram Trigger and the bot never receives messages (no executions): Telegram's servers cannot do the Cloudflare Access email login that gates `n8n.<domain>`. Also the place to look when Telegram deliveries stop after months. Background: [access-jwt](../access-jwt.md), [ci_cd](../ci_cd.md).
**Preconditions:** the workflow with the Telegram Trigger is published in n8n; `GOOGLE_CLOUD_QUOTA_PROJECT` only if you apply Terraform locally (see [cloud](../cloud.md#troubleshooting)).

## How it is set up
- `cloud/main.tf`: Access application `n8n-webhook` with a bypass policy on `n8n.<domain>/webhook/` only. The UI, `/webhook-test/` and every other path stay behind the email login.
- `cloud/waf.tf`, rule `R3`: blocks any request to `/webhook/` on the n8n host that does not come from Telegram's networks (`149.154.160.0/20` and `91.108.4.0/22`, from <https://core.telegram.org/bots/webhooks>).
- `infra/nginx/conf.d/cf-access.conf`, `$cf_access_bypass`: nginx skips the Access JWT check on `/webhook/` for the n8n host, because a bypass policy issues no JWT (without this line nginx answers 401 even though Cloudflare let the request through).
- The Telegram Trigger node restricts the chat ids it answers to, and its webhook path contains an unguessable id. Nothing depends on that id: recreating the workflow or adding another Telegram Trigger needs no Terraform change.

## Steps
1. Change to the setup: edit the files above, open a PR (`apply-cloud.yml` applies on merge).
2. If deliveries stop, open the page above and compare its ranges with `R3`; update `waf.tf` if they changed.
3. A webhook source that is not Telegram needs its own allowance in `R3` (an extra `ip.src` range or a separate path), otherwise the WAF blocks it.

## Verify
- Send a message to the bot from the allowed chat: the workflow's Executions tab shows a run within seconds and the bot answers.
- From any other network the path is closed: `curl -s -o /dev/null -w '%{http_code}\n' https://n8n.<domain>/webhook/00000000-0000-0000-0000-000000000000/webhook` returns 403 (WAF block), and `https://n8n.<domain>/` still redirects to the Access login.

## Rollback
Remove the `n8n_webhook_*` resources from `cloud/main.tf` and rule `R3` from `cloud/waf.tf`, then merge: Telegram can no longer reach n8n and the host is fully behind the login again.

**Last verified:** 2026-11-06 by Claude Code (Telegram messages start the workflow; a request from another network gets 403 from the WAF, the UI and `/webhook-test/` still redirect to the login)
