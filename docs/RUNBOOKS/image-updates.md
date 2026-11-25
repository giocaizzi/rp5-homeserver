# Image updates, rollback and vulnerability scan

**When:** a Dependabot image-bump PR arrives, an image needs a manual bump or rollback, or an Image scan finding needs triage.
**Preconditions:** `gh` access to the repo; SSH to the Pi (`ssh pi.local`) for the emergency rollback and the one-time Shepherd removal.

## How image updates work
- Every `image:` in `infra/docker-compose.yml` and `services/*/docker-compose.yml` is pinned to an **exact version tag**. No auto-pull: nothing changes on the Pi until a release deploys.
- `.github/dependabot.yml` has one `docker-compose` entry per stack directory (`/infra` and `/services/<stack>`), weekly on Monday. Minor and patch bumps arrive as **one grouped PR per stack**, titled `fix(<stack>): bump the <stack> group ...`; majors arrive as individual PRs. ClickHouse is held on the 25.8 LTS line via `ignore`.
- The `fix` type cuts a **patch release** of that component ([releases](../releases.md#commit-contract--bump)). Merging the bump PR stages it; merging the release-please Release PR cuts `<stack>-vX.Y.Z` (infra: `vX.Y.Z`) and fires `deploy-services.yml` (Portainer webhook) or `deploy-infra.yml` (`sync_infra.sh --local`), unchanged.
- Dependabot **security updates do not support `docker-compose`**: only the weekly version updates run. Watch the advisory [Image scan](#vulnerability-scan) for CVEs in between.
- `com.giocaizzi.tier` labels stay (Alloy and Grafana read them) but no longer schedule updates.

## Review and merge a Dependabot PR
1. Read the upstream release notes of every bumped image (linked in the PR body). Look for breaking changes, migrations and config renames.
2. Wait for the required checks `check`, `Validate PR title` and `Leak check`. Read the advisory `Image scan` result for the changed images (see [Vulnerability scan](#vulnerability-scan)); it does not block.
3. Majors: never merge blind. Follow the upstream upgrade guide, take a backup first if the image owns data (Backrest, plan `docker-volumes`), and adjust the compose file in the same PR if needed.
4. Merge it by hand once checks pass (squash). Auto-merge for patch/minor is planned.
5. Merge the Release PR (`chore(repo): release main`) to deploy. The stack restarts once per released bump.
6. Verify: `ssh pi.local 'docker stack services <stack>'` shows the services at desired replicas and the new image tag.

Stopped stacks (`langfuse`, `code`) still get bump PRs and releases, and the release still POSTs their Portainer webhook. After the deploy, check `docker stack ls` on the Pi and stop the stack again if it came up and should stay down.

## Bump an image by hand
1. Edit the tag in the stack's `docker-compose.yml` (exact version, never `latest` or a bare major/minor).
2. `make check`.
3. PR titled `fix(<stack>): bump <image> to <version>` (`fix(infra)` for `infra/`).
4. Merge, then merge the Release PR.

## Roll back
1. Revert the bump: `gh pr revert <pr>` or `git revert <sha>` on a branch.
2. PR title `revert(<stack>): bump <image> to <version>` (or `fix(<stack>): ...`), merge it, then merge the Release PR. Both types cut a patch release and redeploy the previous tag.
3. **Emergency** (service crash-looping now): on the Pi, `docker service rollback <stack>_<svc>`. The next Portainer redeploy (or `sync_infra.sh` run) reapplies `main`, so follow up with the revert above, or the bad tag returns.

## Vulnerability scan
- Workflow `image-scan.yml` ("Image scan"): Trivy scans every image from `docker compose config --images` for `linux/arm64`, severities HIGH and CRITICAL, unfixed CVEs ignored. Runs on PRs touching compose files or `.trivyignore`, weekly on Monday 06:00 UTC, and manually.
- Read results in the job summary (one table per image) or in **Security > Code scanning** (SARIF, one category per image).
- It is **advisory, not a required check**.
- **Accept a finding:** add the CVE ID to `.trivyignore` (one per line) with a comment above it naming the image, the reason and a review date. `exp:YYYY-MM-DD` after the ID makes it expire:
  ```
  # <image>: no fixed release upstream, not reachable (internal network only). Review 2027-03-01.
  CVE-2026-12345 exp:2027-03-01
  ```
- **Promote to required:** set `exit-code: 1` on the Trivy step, add an aggregate job that fails when any scan job failed, then add that job to the required checks of the `main` ruleset.

## One-time Shepherd removal
Shepherd (`infra_shepherd-critical`, `infra_shepherd-core`, `infra_shepherd-extra`) is removed from `infra/docker-compose.yml`. `sync_infra.sh` runs `docker stack deploy` without `--prune`, so the infra release does **not** delete the running services. After that release has deployed:
1. `ssh pi.local 'docker service rm infra_shepherd-critical infra_shepherd-core infra_shepherd-extra'`
2. `ssh pi.local 'docker secret rm infra_shepherd_registries'`
3. Delete `/home/<user>/rp5-homeserver/infra/secrets/shepherd_registries.txt` on the Pi.
4. Delete the Secrets Manager key `infra_shepherd_registries`.

Pinning changes every service's image string, so each stack restarts once when its release deploys.

## Exceptions
- `ghcr.io/giocaizzi/rp5-code:latest` (`services/code`): stays on `latest` until the image publishes version tags.
- `rp5-mcp-stdio` is date-tagged and built by hand ([mcp-stdio.md](../mcp-stdio.md)); Dependabot proposes a bump only after a newer tag is pushed.
- `portainer/portainer-mcp` must stay on the same minor as `portainer/portainer-ee` (see [infra/README.md](../../infra/README.md)): if a Dependabot PR bumps only one of them across a minor, bump the other in the same PR.
- ClickHouse stays on the 25.8 LTS line: bump within it, move to the next LTS deliberately.
