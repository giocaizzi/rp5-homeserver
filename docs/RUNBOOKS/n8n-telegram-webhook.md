# Open the n8n Telegram webhook through Access

**When:** an n8n workflow uses a Telegram Trigger and the bot never receives messages (no executions): Telegram's servers cannot do the Cloudflare Access email login that gates `n8n.<domain>`. Not for other n8n webhooks, which stay behind the login. Background: [access-jwt](../access-jwt.md), [ci_cd](../ci_cd.md) (Terraform variable wiring).
**Preconditions:** the workflow with the Telegram Trigger is published in n8n; `gh` access to this repo; `GOOGLE_CLOUD_QUOTA_PROJECT` only if you apply Terraform locally (see [cloud](../cloud.md#troubleshooting)).

## Steps
1. Read the trigger's webhook id: in n8n open the workflow, the Telegram Trigger node shows the production URL `https://n8n.<domain>/webhook/<id>/webhook`; `<id>` is a UUID (also `webhookId` in the workflow JSON). It changes if the trigger node is deleted and re-created, and is not shown here (it is a private value).
2. Set it as an environment secret on both Terraform environments, from stdin so it never lands in the process list or shell history:
   ```bash
   printf %s "<id>" | gh secret set N8N_TELEGRAM_WEBHOOK_ID -e cloud-plan
   printf %s "<id>" | gh secret set N8N_TELEGRAM_WEBHOOK_ID -e cloud-production
   ```
3. Add the same `<id>` as a line to the `LEAK_PATTERNS` secret (repo and Dependabot) and to the vault note `leak_patterns`, as for any private value.
4. Merge the change in `cloud/`: `apply-cloud.yml` creates a path-scoped Access application (`n8n-telegram-webhook`, bypass) matching only `n8n.<domain>/webhook/<id>/webhook`.
5. Telegram retries failed deliveries, so queued messages may arrive after the path opens. If nothing arrives within a few minutes, unpublish and publish the n8n workflow (n8n registers the webhook again with Telegram).

## Verify
Send a message to the bot from the allowed chat. The workflow's Executions tab shows a run within seconds, and the bot answers. A request to any other path under `n8n.<domain>/webhook/` still gets the Access login page: `curl -s -o /dev/null -w '%{http_code}\n' https://n8n.<domain>/webhook/00000000-0000-0000-0000-000000000000/webhook` returns a redirect (302), not n8n's 404.

## Rollback
Remove the `n8n_telegram_webhook_id` variable, the `n8n_telegram_webhook_*` resources and the `N8N_TELEGRAM_WEBHOOK_ID` wiring, then merge: the Access application is deleted and Telegram can no longer reach n8n. The trigger only answers the chat ids set in the node, so the exposed path alone cannot start the workflow for anyone else.

**Last verified:** not yet verified after apply
