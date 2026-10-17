# Changelog

## [0.3.0](https://github.com/giocaizzi/rp5-homeserver/compare/mcp-connector-v0.2.6...mcp-connector-v0.3.0) (2026-10-17)


### Features

* **mcp-connector:** registry-driven connectors with per-connector groups and audit log ([#405](https://github.com/giocaizzi/rp5-homeserver/issues/405)) ([48b321f](https://github.com/giocaizzi/rp5-homeserver/commit/48b321fbb9f346552cfa5a604a1390ad7d93737e))

## [0.2.6](https://github.com/giocaizzi/rp5-homeserver/compare/mcp-connector-v0.2.5...mcp-connector-v0.2.6) (2026-10-17)


### Bug Fixes

* **mcp-connector:** require consent and allowlisted redirects for OAuth ([#388](https://github.com/giocaizzi/rp5-homeserver/issues/388)) ([d92b481](https://github.com/giocaizzi/rp5-homeserver/commit/d92b481db413c728717415003997252254ee559c))

## [0.2.5](https://github.com/giocaizzi/rp5-homeserver/compare/mcp-connector-v0.2.4...mcp-connector-v0.2.5) (2026-10-15)


### Code Refactoring

* **mcp-connector:** migrate to workers-oauth-provider 1.x ([#379](https://github.com/giocaizzi/rp5-homeserver/issues/379)) ([ddd90f6](https://github.com/giocaizzi/rp5-homeserver/commit/ddd90f6e4d493e7df0c3b54ae13705e6a498b06a))

## [0.2.4](https://github.com/giocaizzi/rp5-homeserver/compare/mcp-connector-v0.2.3...mcp-connector-v0.2.4) (2026-10-12)


### Bug Fixes

* **mcp-connector:** render private config from secrets, not variables ([#339](https://github.com/giocaizzi/rp5-homeserver/issues/339)) ([b756bc8](https://github.com/giocaizzi/rp5-homeserver/commit/b756bc85404ed68ab9cb1edda227dfb4526d61e5))

## [0.2.3](https://github.com/giocaizzi/rp5-homeserver/compare/mcp-connector-v0.2.2...mcp-connector-v0.2.3) (2026-10-12)


### Code Refactoring

* **mcp-connector:** render domain and kv ids into wrangler config at deploy ([#335](https://github.com/giocaizzi/rp5-homeserver/issues/335)) ([b2964cb](https://github.com/giocaizzi/rp5-homeserver/commit/b2964cbd1fa21902194052c561fa4f1287fed134))

## [0.2.2](https://github.com/giocaizzi/rp5-homeserver/compare/mcp-connector-v0.2.1...mcp-connector-v0.2.2) (2026-10-11)


### Bug Fixes

* **mcp-connector:** forward Mcp-Method and Mcp-Name headers upstream ([#318](https://github.com/giocaizzi/rp5-homeserver/issues/318)) ([b5fcf45](https://github.com/giocaizzi/rp5-homeserver/commit/b5fcf45d82574236d32df60e5c0d502fa1339785)), closes [#314](https://github.com/giocaizzi/rp5-homeserver/issues/314)

## [0.2.1](https://github.com/giocaizzi/rp5-homeserver/compare/mcp-connector-v0.2.0...mcp-connector-v0.2.1) (2026-10-11)


### Bug Fixes

* **observability:** require caller token on mcp-grafana ([#298](https://github.com/giocaizzi/rp5-homeserver/issues/298)) ([f26e1fa](https://github.com/giocaizzi/rp5-homeserver/commit/f26e1fa218ca8a0d63e2da1c5626bc29cac4afc5))

## [0.2.0](https://github.com/giocaizzi/rp5-homeserver/compare/mcp-connector-v0.1.1...mcp-connector-v0.2.0) (2026-10-11)


### Features

* **repo:** add grafana, netdata, portainer and langfuse MCP connectors ([#265](https://github.com/giocaizzi/rp5-homeserver/issues/265)) ([3b89a38](https://github.com/giocaizzi/rp5-homeserver/commit/3b89a3826e5320a46cd94bb2c994311eb08ce1c0))

## [0.1.1](https://github.com/giocaizzi/rp5-homeserver/compare/mcp-connector-v0.1.0...mcp-connector-v0.1.1) (2026-10-11)


### Bug Fixes

* **mcp-connector:** pin workers-oauth-provider to 0.8.x ([#255](https://github.com/giocaizzi/rp5-homeserver/issues/255)) ([7498785](https://github.com/giocaizzi/rp5-homeserver/commit/749878554d3b1d2fc2c7eb9163eab50be548c7cb))
