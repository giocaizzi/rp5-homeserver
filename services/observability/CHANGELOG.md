# Changelog

## [0.6.3](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.6.2...observability-v0.6.3) (2026-10-17)


### Documentation

* **observability:** reinstall grafana app plugins after a major upgrade ([#432](https://github.com/giocaizzi/rp5-homeserver/issues/432)) ([3e4cb1c](https://github.com/giocaizzi/rp5-homeserver/commit/3e4cb1c265b50bc25c66b9577353c6f70045b3ec))

## [0.6.2](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.6.1...observability-v0.6.2) (2026-10-17)


### Bug Fixes

* **observability:** drop dead alerts and raise the grafana memory limit ([#429](https://github.com/giocaizzi/rp5-homeserver/issues/429)) ([ec438b5](https://github.com/giocaizzi/rp5-homeserver/commit/ec438b5fb20aed7843c3f78b5782bdb58ed2c5ee))

## [0.6.1](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.6.0...observability-v0.6.1) (2026-10-17)


### Bug Fixes

* **observability:** let tempo accept grafana's last-24h range ([#425](https://github.com/giocaizzi/rp5-homeserver/issues/425)) ([d35fd64](https://github.com/giocaizzi/rp5-homeserver/commit/d35fd646b6295cd3e4bf926d17c8b4701eef7098))

## [0.6.0](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.5.6...observability-v0.6.0) (2026-10-17)


### Features

* **observability:** upgrade loki to 3.7.8 and grafana to 13.2.4 ([#424](https://github.com/giocaizzi/rp5-homeserver/issues/424)) ([a1532b1](https://github.com/giocaizzi/rp5-homeserver/commit/a1532b1a29866af480605a4cdac7c3fbce7390b0))

## [0.5.6](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.5.5...observability-v0.5.6) (2026-10-17)


### Bug Fixes

* **observability:** widen tempo metrics range and allow public grafana live origin ([#418](https://github.com/giocaizzi/rp5-homeserver/issues/418)) ([94ffece](https://github.com/giocaizzi/rp5-homeserver/commit/94ffeced36aa8742c7ee730ed1afd8c231f7cb27))

## [0.5.5](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.5.4...observability-v0.5.5) (2026-10-17)


### Bug Fixes

* **observability:** enable tempo local-blocks for traceql metrics ([#415](https://github.com/giocaizzi/rp5-homeserver/issues/415)) ([e2e5459](https://github.com/giocaizzi/rp5-homeserver/commit/e2e5459e17c2719ddddd197ab8ad4e8268f9e08d))

## [0.5.4](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.5.3...observability-v0.5.4) (2026-10-17)


### Bug Fixes

* **observability:** pin the grafana mcp sidecar image ([#390](https://github.com/giocaizzi/rp5-homeserver/issues/390)) ([d2b6087](https://github.com/giocaizzi/rp5-homeserver/commit/d2b608743a75fa18e36090936f021867335d2189))


### Documentation

* point stale claude.md references at agents.md ([#382](https://github.com/giocaizzi/rp5-homeserver/issues/382)) ([d9f9cd6](https://github.com/giocaizzi/rp5-homeserver/commit/d9f9cd641dbb10d622b8a6778e2fcb336cdbc5b8))

## [0.5.3](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.5.2...observability-v0.5.3) (2026-10-15)


### Bug Fixes

* **observability:** demote firefly static cron token log line to warn ([#368](https://github.com/giocaizzi/rp5-homeserver/issues/368)) ([da8ae3d](https://github.com/giocaizzi/rp5-homeserver/commit/da8ae3de0d502cbea758c8d52a2be96a0c70230f))

## [0.5.2](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.5.1...observability-v0.5.2) (2026-10-15)


### Bug Fixes

* **observability:** drop nginx silent alert and demote tempo restart races ([#366](https://github.com/giocaizzi/rp5-homeserver/issues/366)) ([3b70d3f](https://github.com/giocaizzi/rp5-homeserver/commit/3b70d3f661f0f586600257f4105ceb69421df5c6))

## [0.5.1](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.5.0...observability-v0.5.1) (2026-10-12)


### Bug Fixes

* **observability:** show data in the API Error Rate panel ([#357](https://github.com/giocaizzi/rp5-homeserver/issues/357)) ([9c2201a](https://github.com/giocaizzi/rp5-homeserver/commit/9c2201aebd3cab89be9cd092c9009a11c84476d3))

## [0.5.0](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.7...observability-v0.5.0) (2026-10-12)


### Features

* **observability:** add a Guard row to the Claude Code dashboard ([#355](https://github.com/giocaizzi/rp5-homeserver/issues/355)) ([28757d0](https://github.com/giocaizzi/rp5-homeserver/commit/28757d0e418fc9f59bfd4bec383fa76307ff3103))

## [0.4.7](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.6...observability-v0.4.7) (2026-10-12)


### Code Refactoring

* **observability:** neutral uids for the website dashboards ([#350](https://github.com/giocaizzi/rp5-homeserver/issues/350)) ([3e539e0](https://github.com/giocaizzi/rp5-homeserver/commit/3e539e0f068d9a1a8f79ce1c2a3dd1259570e429))

## [0.4.6](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.5...observability-v0.4.6) (2026-10-12)


### Code Refactoring

* **observability:** neutral name for the website dashboards ([#347](https://github.com/giocaizzi/rp5-homeserver/issues/347)) ([1172d0e](https://github.com/giocaizzi/rp5-homeserver/commit/1172d0efa4deb82c8265971672e5fd9587d18541))

## [0.4.5](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.4...observability-v0.4.5) (2026-10-12)


### Code Refactoring

* **repo:** read the public domain from the stack env in service stacks ([#337](https://github.com/giocaizzi/rp5-homeserver/issues/337)) ([0919adb](https://github.com/giocaizzi/rp5-homeserver/commit/0919adb1fb181b882be843d56194d9e340685910))

## [0.4.4](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.3...observability-v0.4.4) (2026-10-11)


### Bug Fixes

* **observability:** add empty grafana provisioning/plugins dir ([#319](https://github.com/giocaizzi/rp5-homeserver/issues/319)) ([d12fcdb](https://github.com/giocaizzi/rp5-homeserver/commit/d12fcdb461a2b6c580f79ecea230264788298ddb)), closes [#313](https://github.com/giocaizzi/rp5-homeserver/issues/313)
* **observability:** drop netdata cgroup-network PID resolution noise ([#322](https://github.com/giocaizzi/rp5-homeserver/issues/322)) ([76571ca](https://github.com/giocaizzi/rp5-homeserver/commit/76571cabcb40a2ed9c2ba747e95941a2b770c25d)), closes [#292](https://github.com/giocaizzi/rp5-homeserver/issues/292)

## [0.4.3](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.2...observability-v0.4.3) (2026-10-11)


### Bug Fixes

* **observability:** raise nginx 5xx alert min error count to 20 ([#307](https://github.com/giocaizzi/rp5-homeserver/issues/307)) ([74e9916](https://github.com/giocaizzi/rp5-homeserver/commit/74e99168f25dcd5e913199043ce63b31a0be7285))

## [0.4.2](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.1...observability-v0.4.2) (2026-10-11)


### Bug Fixes

* **crm:** scrape crm-redis and alert on missing redis metrics ([#287](https://github.com/giocaizzi/rp5-homeserver/issues/287)) ([c6cf31a](https://github.com/giocaizzi/rp5-homeserver/commit/c6cf31a25cf3c8cf570dcde0fe0511c5dbd8d67a))
* **observability:** drop log lines older than Loki's 7d write window ([#286](https://github.com/giocaizzi/rp5-homeserver/issues/286)) ([275671a](https://github.com/giocaizzi/rp5-homeserver/commit/275671a675c273cbbade178394e285e737b072a5))
* **observability:** exclude unexpected EOF from container error burst alert ([#283](https://github.com/giocaizzi/rp5-homeserver/issues/283)) ([9904220](https://github.com/giocaizzi/rp5-homeserver/commit/99042200ecd8fe043d780243fced4fbaf662ea25))
* **observability:** extend tempo stop grace period to 90s ([#295](https://github.com/giocaizzi/rp5-homeserver/issues/295)) ([1a7fda9](https://github.com/giocaizzi/rp5-homeserver/commit/1a7fda9414be78de07b7f68c4e378d7af517622c)), closes [#290](https://github.com/giocaizzi/rp5-homeserver/issues/290)
* **observability:** fix malformed grafana ntfy notifications ([#285](https://github.com/giocaizzi/rp5-homeserver/issues/285)) ([a660e14](https://github.com/giocaizzi/rp5-homeserver/commit/a660e148d7add875236c79d117a34d6588d6e5c8)), closes [#280](https://github.com/giocaizzi/rp5-homeserver/issues/280)
* **observability:** require caller token on mcp-grafana ([#298](https://github.com/giocaizzi/rp5-homeserver/issues/298)) ([f26e1fa](https://github.com/giocaizzi/rp5-homeserver/commit/f26e1fa218ca8a0d63e2da1c5626bc29cac4afc5))
* **observability:** set GRAFANA_ORG_ID on mcp-grafana ([#301](https://github.com/giocaizzi/rp5-homeserver/issues/301)) ([29dcef0](https://github.com/giocaizzi/rp5-homeserver/commit/29dcef05ff8543c580b1a5dd95839d9324f9b153))
* **observability:** shorten alloy docker discovery refresh to drop stale tailers ([#297](https://github.com/giocaizzi/rp5-homeserver/issues/297)) ([69e2f5a](https://github.com/giocaizzi/rp5-homeserver/commit/69e2f5a78ac10c2060f84fd23c5d23de4f5f18ec)), closes [#288](https://github.com/giocaizzi/rp5-homeserver/issues/288)

## [0.4.1](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.0...observability-v0.4.1) (2026-10-11)


### Bug Fixes

* **observability:** allow public host in grafana-mcp host check ([#270](https://github.com/giocaizzi/rp5-homeserver/issues/270)) ([2ecfa61](https://github.com/giocaizzi/rp5-homeserver/commit/2ecfa61f5cf8d0f611015d6fb40a9fc1f0077263))

## [0.4.0](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.3.0...observability-v0.4.0) (2026-10-11)


### Features

* **repo:** add grafana, netdata, portainer and langfuse MCP connectors ([#265](https://github.com/giocaizzi/rp5-homeserver/issues/265)) ([3b89a38](https://github.com/giocaizzi/rp5-homeserver/commit/3b89a3826e5320a46cd94bb2c994311eb08ce1c0))

## [0.3.0](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.2.0...observability-v0.3.0) (2026-10-11)


### Features

* **observability:** alert on nginx 5xx ratio, silent nginx logs and container error bursts ([#256](https://github.com/giocaizzi/rp5-homeserver/issues/256)) ([bf478b9](https://github.com/giocaizzi/rp5-homeserver/commit/bf478b9545720627c67a42487b4fcc5a2793f8c4))
* **observability:** detect more log levels and alert on tunnel outages ([#258](https://github.com/giocaizzi/rp5-homeserver/issues/258)) ([18b319a](https://github.com/giocaizzi/rp5-homeserver/commit/18b319a98396f033e9bd64ca052e9dac36a7739f))

## [0.2.0](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.7...observability-v0.2.0) (2026-10-04)


### Features

* **observability:** route grafana alerts to ntfy ([#244](https://github.com/giocaizzi/rp5-homeserver/issues/244)) ([952d6e5](https://github.com/giocaizzi/rp5-homeserver/commit/952d6e5cce2a4917aae25d6c6f6423e12edfe55b))

## [0.1.7](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.6...observability-v0.1.7) (2026-10-03)


### Bug Fixes

* **observability:** tune alloy, tempo, loki, prometheus and grafana for enforced memory limits ([#232](https://github.com/giocaizzi/rp5-homeserver/issues/232)) ([83779df](https://github.com/giocaizzi/rp5-homeserver/commit/83779df809554a0c2dd8e6a22edb0f156d67f403))

## [0.1.6](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.5...observability-v0.1.6) (2026-10-03)


### Bug Fixes

* **observability:** raise tempo, loki and collector memory limits ([#219](https://github.com/giocaizzi/rp5-homeserver/issues/219)) ([9b0dc33](https://github.com/giocaizzi/rp5-homeserver/commit/9b0dc3376546ff44531754855d092fc762307d45))

## [0.1.5](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.4...observability-v0.1.5) (2026-10-03)


### Bug Fixes

* **observability:** replace empty skill cost panels with skill activations ([#214](https://github.com/giocaizzi/rp5-homeserver/issues/214)) ([060264d](https://github.com/giocaizzi/rp5-homeserver/commit/060264d875ee1a5db6e2909f500ec9a886039b64)), closes [#153](https://github.com/giocaizzi/rp5-homeserver/issues/153)

## [0.1.4](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.3...observability-v0.1.4) (2026-10-03)


### Bug Fixes

* **observability:** drop unattributed "Value" bar from skill/MCP cost panels ([#153](https://github.com/giocaizzi/rp5-homeserver/issues/153)) ([#201](https://github.com/giocaizzi/rp5-homeserver/issues/201)) ([ab73245](https://github.com/giocaizzi/rp5-homeserver/commit/ab732454eeda6fa3225dad543c8a39c6c7c09023))

## [0.1.3](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.2...observability-v0.1.3) (2026-10-03)


### Bug Fixes

* **observability:** raise grafana memory limit to 384M ([#196](https://github.com/giocaizzi/rp5-homeserver/issues/196)) ([2c79f4c](https://github.com/giocaizzi/rp5-homeserver/commit/2c79f4c906a5a6543277df97227b507006cd94ab))

## [0.1.2](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.1...observability-v0.1.2) (2026-10-03)


### Bug Fixes

* **observability:** roll tasks on release and size alloy memory ([#191](https://github.com/giocaizzi/rp5-homeserver/issues/191)) ([f8319c7](https://github.com/giocaizzi/rp5-homeserver/commit/f8319c7cc3282b78238e2582bf173d816a41da8d))

## [0.1.1](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.0...observability-v0.1.1) (2026-10-03)


### Bug Fixes

* **observability:** raise otel memory_limiter above alloy baseline ([#189](https://github.com/giocaizzi/rp5-homeserver/issues/189)) ([7dcfda6](https://github.com/giocaizzi/rp5-homeserver/commit/7dcfda6cd1ddab3d2baf0624b5acf1da4f59d760))
