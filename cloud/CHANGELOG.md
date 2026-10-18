# Changelog

## [0.11.0](https://github.com/giocaizzi/rp5-homeserver/compare/cloud-v0.10.0...cloud-v0.11.0) (2026-10-18)


### Features

* **cloud:** add Access for the lamma MCP server ([#482](https://github.com/giocaizzi/rp5-homeserver/issues/482)) ([adc6dd9](https://github.com/giocaizzi/rp5-homeserver/commit/adc6dd973b185118bddf23094db278b925267bcc))

## [0.10.0](https://github.com/giocaizzi/rp5-homeserver/compare/cloud-v0.9.0...cloud-v0.10.0) (2026-10-18)


### Features

* **cloud:** add Access for the surfline MCP server ([#473](https://github.com/giocaizzi/rp5-homeserver/issues/473)) ([0e09958](https://github.com/giocaizzi/rp5-homeserver/commit/0e09958bb128b40b0938c8d2b970bbefd26f1036))

## [0.9.0](https://github.com/giocaizzi/rp5-homeserver/compare/cloud-v0.8.0...cloud-v0.9.0) (2026-10-17)


### Features

* **cloud:** access app and service token for the garmin mcp ([#436](https://github.com/giocaizzi/rp5-homeserver/issues/436)) ([1b60752](https://github.com/giocaizzi/rp5-homeserver/commit/1b60752af8cdf1835244a05b4d34d868eca162db))

## [0.8.0](https://github.com/giocaizzi/rp5-homeserver/compare/cloud-v0.7.1...cloud-v0.8.0) (2026-10-17)


### Features

* **cloud:** add the mcp-stdio host and the fli MCP Access app ([#407](https://github.com/giocaizzi/rp5-homeserver/issues/407)) ([e4813af](https://github.com/giocaizzi/rp5-homeserver/commit/e4813af8a9f9a69d0e5c887bcf9c1044d6a07bf5))

## [0.7.1](https://github.com/giocaizzi/rp5-homeserver/compare/cloud-v0.7.0...cloud-v0.7.1) (2026-10-17)


### Documentation

* **cloud:** correct the otel access app comment ([#391](https://github.com/giocaizzi/rp5-homeserver/issues/391)) ([c3ee8ef](https://github.com/giocaizzi/rp5-homeserver/commit/c3ee8ef75316116eff0fe99ea553701ff30dbb27))

## [0.7.0](https://github.com/giocaizzi/rp5-homeserver/compare/cloud-v0.6.2...cloud-v0.7.0) (2026-10-15)


### Features

* **cloud:** allow per-user oauth for crm mcp ([#375](https://github.com/giocaizzi/rp5-homeserver/issues/375)) ([c3d0cf6](https://github.com/giocaizzi/rp5-homeserver/commit/c3d0cf664fa8d6654b31af57e58fdf0a69da4bce))


### Bug Fixes

* **cloud:** delete the retired crm mcp service token and policy ([#378](https://github.com/giocaizzi/rp5-homeserver/issues/378)) ([f921ce0](https://github.com/giocaizzi/rp5-homeserver/commit/f921ce06c280252770f766a2b0ecf8726a3141d8))
* **cloud:** unblock crm mcp apply by retiring the old policy in two steps ([#377](https://github.com/giocaizzi/rp5-homeserver/issues/377)) ([43a669f](https://github.com/giocaizzi/rp5-homeserver/commit/43a669f193244b995ede6299504324f8025f2321))

## [0.6.2](https://github.com/giocaizzi/rp5-homeserver/compare/cloud-v0.6.1...cloud-v0.6.2) (2026-10-15)


### Bug Fixes

* **cloud:** keep crm /graphql under the ui access app ([#371](https://github.com/giocaizzi/rp5-homeserver/issues/371)) ([a379b11](https://github.com/giocaizzi/rp5-homeserver/commit/a379b11913da02c8878edaf90abe697fb37a9748))

## [0.6.1](https://github.com/giocaizzi/rp5-homeserver/compare/cloud-v0.6.0...cloud-v0.6.1) (2026-10-12)


### Bug Fixes

* **cloud:** keep private terraform inputs out of public logs ([#342](https://github.com/giocaizzi/rp5-homeserver/issues/342)) ([580a461](https://github.com/giocaizzi/rp5-homeserver/commit/580a461d64b71134f5b4b9a9f4718b4d53c68194))


### Code Refactoring

* **cloud:** give the crm api service token a generic name ([#336](https://github.com/giocaizzi/rp5-homeserver/issues/336)) ([1293b0f](https://github.com/giocaizzi/rp5-homeserver/commit/1293b0fd572e163e72bdfe6b5cc7bdde216026af))

## [0.6.0](https://github.com/giocaizzi/rp5-homeserver/compare/cloud-v0.5.0...cloud-v0.6.0) (2026-10-11)


### Features

* **cloud:** add calibre public hostname and Access app ([#264](https://github.com/giocaizzi/rp5-homeserver/issues/264)) ([8e35250](https://github.com/giocaizzi/rp5-homeserver/commit/8e352508252265a9ceddab63c620b63def17d0ea))
* **repo:** add grafana, netdata, portainer and langfuse MCP connectors ([#265](https://github.com/giocaizzi/rp5-homeserver/issues/265)) ([3b89a38](https://github.com/giocaizzi/rp5-homeserver/commit/3b89a3826e5320a46cd94bb2c994311eb08ce1c0))

## [0.5.0](https://github.com/giocaizzi/rp5-homeserver/compare/cloud-v0.4.0...cloud-v0.5.0) (2026-10-04)


### Features

* **cloud:** expose ntfy through the tunnel ([#241](https://github.com/giocaizzi/rp5-homeserver/issues/241)) ([67045a4](https://github.com/giocaizzi/rp5-homeserver/commit/67045a4a90df323ee86d4a592e118aef34c8ea1e))

## [0.4.0](https://github.com/giocaizzi/rp5-homeserver/compare/cloud-v0.3.0...cloud-v0.4.0) (2026-10-03)


### Features

* **repo:** materialise infra secrets from bitwarden secrets manager ([#230](https://github.com/giocaizzi/rp5-homeserver/issues/230)) ([165c13f](https://github.com/giocaizzi/rp5-homeserver/commit/165c13fadae793e8b3803d05906f9d015d6ae530))

## [0.3.0](https://github.com/giocaizzi/rp5-homeserver/compare/cloud-v0.2.0...cloud-v0.3.0) (2026-09-27)


### Features

* **cloud:** expose Twenty CRM at crm.<domain> ([#169](https://github.com/giocaizzi/rp5-homeserver/issues/169)) ([58ce8d4](https://github.com/giocaizzi/rp5-homeserver/commit/58ce8d4b8cb8e50371d6fd352ddbafc4d5c1286b))

## [0.2.0](https://github.com/giocaizzi/rp5-homeserver/compare/cloud-v0.1.0...cloud-v0.2.0) (2026-06-24)


### Features

* **code:** remote Claude Code dev environment (CloudCLI) ([#149](https://github.com/giocaizzi/rp5-homeserver/issues/149)) ([dbce3ac](https://github.com/giocaizzi/rp5-homeserver/commit/dbce3ac1df062063856db600f35d004246b53702))
