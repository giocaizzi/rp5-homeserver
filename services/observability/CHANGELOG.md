# Changelog

## [0.5.0](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.7...observability-v0.5.0) (2026-10-12)


### Features

* **observability:** add a Guard row to the Claude Code dashboard ([#355](https://github.com/giocaizzi/rp5-homeserver/issues/355)) ([5c0f97c](https://github.com/giocaizzi/rp5-homeserver/commit/5c0f97c29445a9f04be9c72ee724b1d7dec616b3))

## [0.4.7](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.6...observability-v0.4.7) (2026-10-12)


### Code Refactoring

* **observability:** neutral uids for the website dashboards ([#350](https://github.com/giocaizzi/rp5-homeserver/issues/350)) ([29bbb69](https://github.com/giocaizzi/rp5-homeserver/commit/29bbb691907846354db846eb70893da682c0821d))

## [0.4.6](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.5...observability-v0.4.6) (2026-10-12)


### Code Refactoring

* **observability:** neutral name for the website dashboards ([#347](https://github.com/giocaizzi/rp5-homeserver/issues/347)) ([f1ff420](https://github.com/giocaizzi/rp5-homeserver/commit/f1ff420b117c8839bc9f913c70cad9a7e2cf3f36))

## [0.4.5](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.4...observability-v0.4.5) (2026-10-12)


### Code Refactoring

* **repo:** read the public domain from the stack env in service stacks ([#337](https://github.com/giocaizzi/rp5-homeserver/issues/337)) ([56f387a](https://github.com/giocaizzi/rp5-homeserver/commit/56f387af39ba8012fb18708f5ba874eb6d327818))

## [0.4.4](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.3...observability-v0.4.4) (2026-10-11)


### Bug Fixes

* **observability:** add empty grafana provisioning/plugins dir ([#319](https://github.com/giocaizzi/rp5-homeserver/issues/319)) ([83ab924](https://github.com/giocaizzi/rp5-homeserver/commit/83ab924f7cab539bfd1856a75a7bf3b3a78fec63)), closes [#313](https://github.com/giocaizzi/rp5-homeserver/issues/313)
* **observability:** drop netdata cgroup-network PID resolution noise ([#322](https://github.com/giocaizzi/rp5-homeserver/issues/322)) ([19e6e99](https://github.com/giocaizzi/rp5-homeserver/commit/19e6e99fdd2ecbbb34d29043b0a622f8a6ae3794)), closes [#292](https://github.com/giocaizzi/rp5-homeserver/issues/292)

## [0.4.3](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.2...observability-v0.4.3) (2026-10-11)


### Bug Fixes

* **observability:** raise nginx 5xx alert min error count to 20 ([#307](https://github.com/giocaizzi/rp5-homeserver/issues/307)) ([20bf99a](https://github.com/giocaizzi/rp5-homeserver/commit/20bf99a1c0c06b71e17792ec3f3f30c69f967e43))

## [0.4.2](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.1...observability-v0.4.2) (2026-10-11)


### Bug Fixes

* **crm:** scrape crm-redis and alert on missing redis metrics ([#287](https://github.com/giocaizzi/rp5-homeserver/issues/287)) ([a24364c](https://github.com/giocaizzi/rp5-homeserver/commit/a24364c91b1f73e1d1ddbf939bc01d6ab7918194))
* **observability:** drop log lines older than Loki's 7d write window ([#286](https://github.com/giocaizzi/rp5-homeserver/issues/286)) ([499da64](https://github.com/giocaizzi/rp5-homeserver/commit/499da64a3262118b1419ee23654aeba9c63d1ba4))
* **observability:** exclude unexpected EOF from container error burst alert ([#283](https://github.com/giocaizzi/rp5-homeserver/issues/283)) ([b268f4f](https://github.com/giocaizzi/rp5-homeserver/commit/b268f4f083143c530750abad02738fca5e78a71b))
* **observability:** extend tempo stop grace period to 90s ([#295](https://github.com/giocaizzi/rp5-homeserver/issues/295)) ([ecfff34](https://github.com/giocaizzi/rp5-homeserver/commit/ecfff349d556e578516638bb995d2c94255f5035)), closes [#290](https://github.com/giocaizzi/rp5-homeserver/issues/290)
* **observability:** fix malformed grafana ntfy notifications ([#285](https://github.com/giocaizzi/rp5-homeserver/issues/285)) ([e08ba2a](https://github.com/giocaizzi/rp5-homeserver/commit/e08ba2a6ca9e6ea1497e5e196e5c958c62d43769)), closes [#280](https://github.com/giocaizzi/rp5-homeserver/issues/280)
* **observability:** require caller token on mcp-grafana ([#298](https://github.com/giocaizzi/rp5-homeserver/issues/298)) ([5eca84d](https://github.com/giocaizzi/rp5-homeserver/commit/5eca84d0cbcb5edcba63eae353a215d2932b752f))
* **observability:** set GRAFANA_ORG_ID on mcp-grafana ([#301](https://github.com/giocaizzi/rp5-homeserver/issues/301)) ([606f0d5](https://github.com/giocaizzi/rp5-homeserver/commit/606f0d5e5b484452c1b226e6f636a76576773128))
* **observability:** shorten alloy docker discovery refresh to drop stale tailers ([#297](https://github.com/giocaizzi/rp5-homeserver/issues/297)) ([ab98a58](https://github.com/giocaizzi/rp5-homeserver/commit/ab98a5821dbc8993852db155183a091eabf5133c)), closes [#288](https://github.com/giocaizzi/rp5-homeserver/issues/288)

## [0.4.1](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.4.0...observability-v0.4.1) (2026-10-11)


### Bug Fixes

* **observability:** allow public host in grafana-mcp host check ([#270](https://github.com/giocaizzi/rp5-homeserver/issues/270)) ([0b08a20](https://github.com/giocaizzi/rp5-homeserver/commit/0b08a2092c7b582f72a18a42bc447916f0ce82d2))

## [0.4.0](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.3.0...observability-v0.4.0) (2026-10-11)


### Features

* **repo:** add grafana, netdata, portainer and langfuse MCP connectors ([#265](https://github.com/giocaizzi/rp5-homeserver/issues/265)) ([501b368](https://github.com/giocaizzi/rp5-homeserver/commit/501b368ec3ded859387df863fa7d57c8b623fa7d))

## [0.3.0](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.2.0...observability-v0.3.0) (2026-10-11)


### Features

* **observability:** alert on nginx 5xx ratio, silent nginx logs and container error bursts ([#256](https://github.com/giocaizzi/rp5-homeserver/issues/256)) ([cde8a6f](https://github.com/giocaizzi/rp5-homeserver/commit/cde8a6f45bcef8ac7116047d28c950b391a2d69f))
* **observability:** detect more log levels and alert on tunnel outages ([#258](https://github.com/giocaizzi/rp5-homeserver/issues/258)) ([188f51d](https://github.com/giocaizzi/rp5-homeserver/commit/188f51d671b9b4445ba103f0e1356da29e295c5e))

## [0.2.0](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.7...observability-v0.2.0) (2026-10-04)


### Features

* **observability:** route grafana alerts to ntfy ([#244](https://github.com/giocaizzi/rp5-homeserver/issues/244)) ([3a2238a](https://github.com/giocaizzi/rp5-homeserver/commit/3a2238a54a11a5b402c18180beafca0b8bd1cadc))

## [0.1.7](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.6...observability-v0.1.7) (2026-10-03)


### Bug Fixes

* **observability:** tune alloy, tempo, loki, prometheus and grafana for enforced memory limits ([#232](https://github.com/giocaizzi/rp5-homeserver/issues/232)) ([cf198e9](https://github.com/giocaizzi/rp5-homeserver/commit/cf198e9f66b86b6d91112d20d8236a349f8ee9ad))

## [0.1.6](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.5...observability-v0.1.6) (2026-10-03)


### Bug Fixes

* **observability:** raise tempo, loki and collector memory limits ([#219](https://github.com/giocaizzi/rp5-homeserver/issues/219)) ([dfba939](https://github.com/giocaizzi/rp5-homeserver/commit/dfba93942766de1063a97cf592ba076d0ebcef22))

## [0.1.5](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.4...observability-v0.1.5) (2026-10-03)


### Bug Fixes

* **observability:** replace empty skill cost panels with skill activations ([#214](https://github.com/giocaizzi/rp5-homeserver/issues/214)) ([fa13b79](https://github.com/giocaizzi/rp5-homeserver/commit/fa13b79210ddc16bede62f8ff94d3ecd4388aab0)), closes [#153](https://github.com/giocaizzi/rp5-homeserver/issues/153)

## [0.1.4](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.3...observability-v0.1.4) (2026-10-03)


### Bug Fixes

* **observability:** drop unattributed "Value" bar from skill/MCP cost panels ([#153](https://github.com/giocaizzi/rp5-homeserver/issues/153)) ([#201](https://github.com/giocaizzi/rp5-homeserver/issues/201)) ([67d5ee2](https://github.com/giocaizzi/rp5-homeserver/commit/67d5ee21948bd79ddacc6750ba4530ef49540ebc))

## [0.1.3](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.2...observability-v0.1.3) (2026-10-03)


### Bug Fixes

* **observability:** raise grafana memory limit to 384M ([#196](https://github.com/giocaizzi/rp5-homeserver/issues/196)) ([759715e](https://github.com/giocaizzi/rp5-homeserver/commit/759715e38e1e5e3d757a0a16b8ed72044ffd43af))

## [0.1.2](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.1...observability-v0.1.2) (2026-10-03)


### Bug Fixes

* **observability:** roll tasks on release and size alloy memory ([#191](https://github.com/giocaizzi/rp5-homeserver/issues/191)) ([1a1bb07](https://github.com/giocaizzi/rp5-homeserver/commit/1a1bb0737620c1bedc7191643bdc5a6a4304af35))

## [0.1.1](https://github.com/giocaizzi/rp5-homeserver/compare/observability-v0.1.0...observability-v0.1.1) (2026-10-03)


### Bug Fixes

* **observability:** raise otel memory_limiter above alloy baseline ([#189](https://github.com/giocaizzi/rp5-homeserver/issues/189)) ([3dac462](https://github.com/giocaizzi/rp5-homeserver/commit/3dac46262bd3ed934e1f37495811bb31dba61ef2))
