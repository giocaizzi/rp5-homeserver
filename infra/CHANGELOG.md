# Changelog

## [1.20.0](https://github.com/giocaizzi/rp5-homeserver/compare/v1.19.6...v1.20.0) (2026-10-17)


### Features

* **infra:** route mcp-stdio host to the stdio MCP gateway ([#406](https://github.com/giocaizzi/rp5-homeserver/issues/406)) ([9c3a033](https://github.com/giocaizzi/rp5-homeserver/commit/9c3a0332ffdca35c245b368ed977c4dfef0bd27e))
* **infra:** verify the Cloudflare Access JWT at nginx behind a per-host flag ([#412](https://github.com/giocaizzi/rp5-homeserver/issues/412)) ([51445f3](https://github.com/giocaizzi/rp5-homeserver/commit/51445f38811dfee0168f70a2934faef17d79efea))


### Bug Fixes

* **infra:** keep calibre kobo logs token-free on errors and parseable ([#411](https://github.com/giocaizzi/rp5-homeserver/issues/411)) ([4601acb](https://github.com/giocaizzi/rp5-homeserver/commit/4601acbef0e24a23bfce6069f0c1b24fc718623f))
* **infra:** rate-limit calibre reader paths and keep the kobo token out of logs ([#404](https://github.com/giocaizzi/rp5-homeserver/issues/404)) ([b9f89ed](https://github.com/giocaizzi/rp5-homeserver/commit/b9f89edee95067568f68201833cf67eade901b0a))

## [1.19.6](https://github.com/giocaizzi/rp5-homeserver/compare/v1.19.5...v1.19.6) (2026-10-17)


### Bug Fixes

* **infra:** stop proxying non-OTLP paths on the otel host ([#389](https://github.com/giocaizzi/rp5-homeserver/issues/389)) ([c6d4164](https://github.com/giocaizzi/rp5-homeserver/commit/c6d4164f4f5835a6dfd1af897fffdf6b133ef517))

## [1.19.5](https://github.com/giocaizzi/rp5-homeserver/compare/v1.19.4...v1.19.5) (2026-10-15)


### Bug Fixes

* **infra:** stop proxy and monitoring cleanly on update ([#374](https://github.com/giocaizzi/rp5-homeserver/issues/374)) ([717b6e5](https://github.com/giocaizzi/rp5-homeserver/commit/717b6e5f4283a7ad891b32ba06e8d69fc473f415))

## [1.19.4](https://github.com/giocaizzi/rp5-homeserver/compare/v1.19.3...v1.19.4) (2026-10-15)


### Bug Fixes

* **infra:** raise management-mcp memory limit to 256M ([#364](https://github.com/giocaizzi/rp5-homeserver/issues/364)) ([802ae3c](https://github.com/giocaizzi/rp5-homeserver/commit/802ae3c100f7b628384fea0ff9c6d07e27e18bcf))

## [1.19.3](https://github.com/giocaizzi/rp5-homeserver/compare/v1.19.2...v1.19.3) (2026-10-12)


### Code Refactoring

* **infra:** stop committing the public domain and pi user in infra ([#343](https://github.com/giocaizzi/rp5-homeserver/issues/343)) ([f0a4724](https://github.com/giocaizzi/rp5-homeserver/commit/f0a47247bba59a02117a053ab012401c9e61f74a))

## [1.19.2](https://github.com/giocaizzi/rp5-homeserver/compare/v1.19.1...v1.19.2) (2026-10-11)


### Bug Fixes

* **infra:** run shepherd under an init so it stops on SIGTERM ([#321](https://github.com/giocaizzi/rp5-homeserver/issues/321)) ([1605c4f](https://github.com/giocaizzi/rp5-homeserver/commit/1605c4f20f6c7d3a4a380773161b333879bb44d7)), closes [#316](https://github.com/giocaizzi/rp5-homeserver/issues/316)

## [1.19.1](https://github.com/giocaizzi/rp5-homeserver/compare/v1.19.0...v1.19.1) (2026-10-11)


### Bug Fixes

* **infra:** mount netdata pi_temp alarm as a file, not a read-only directory ([#310](https://github.com/giocaizzi/rp5-homeserver/issues/310)) ([d5b5512](https://github.com/giocaizzi/rp5-homeserver/commit/d5b55122a26ff9fbdefd630bd7ee49a922296287))

## [1.19.0](https://github.com/giocaizzi/rp5-homeserver/compare/v1.18.1...v1.19.0) (2026-10-11)


### Features

* **infra:** add netdata pi cpu temperature alert ([#308](https://github.com/giocaizzi/rp5-homeserver/issues/308)) ([4eb39f3](https://github.com/giocaizzi/rp5-homeserver/commit/4eb39f3e54827ec33f0abe60117276b2c368ed12))

## [1.18.1](https://github.com/giocaizzi/rp5-homeserver/compare/v1.18.0...v1.18.1) (2026-10-11)


### Bug Fixes

* **infra:** return 429 on nginx rate limit and raise homepage burst ([#284](https://github.com/giocaizzi/rp5-homeserver/issues/284)) ([0f82682](https://github.com/giocaizzi/rp5-homeserver/commit/0f82682a4d1c7756e01dafb72509dd6a3fe36d69))
* **infra:** unquote version in homepage greeting widget ([#294](https://github.com/giocaizzi/rp5-homeserver/issues/294)) ([969184f](https://github.com/giocaizzi/rp5-homeserver/commit/969184fcaa018954ef1778d1c3c76e4d2da07939)), closes [#185](https://github.com/giocaizzi/rp5-homeserver/issues/185)

## [1.18.0](https://github.com/giocaizzi/rp5-homeserver/compare/v1.17.1...v1.18.0) (2026-10-11)


### Features

* **infra:** route calibre.<domain> ([#263](https://github.com/giocaizzi/rp5-homeserver/issues/263)) ([6a08b06](https://github.com/giocaizzi/rp5-homeserver/commit/6a08b064527a18b44812f084d6529acc13eb3733))
* **repo:** add grafana, netdata, portainer and langfuse MCP connectors ([#265](https://github.com/giocaizzi/rp5-homeserver/issues/265)) ([3b89a38](https://github.com/giocaizzi/rp5-homeserver/commit/3b89a3826e5320a46cd94bb2c994311eb08ce1c0))

## [1.17.1](https://github.com/giocaizzi/rp5-homeserver/compare/v1.17.0...v1.17.1) (2026-10-04)


### Bug Fixes

* **infra:** filter netdata ntfy alerts to critical in the notify config ([#246](https://github.com/giocaizzi/rp5-homeserver/issues/246)) ([de15af7](https://github.com/giocaizzi/rp5-homeserver/commit/de15af7e723c3743519b5f63d06389499c76e69a))

## [1.17.0](https://github.com/giocaizzi/rp5-homeserver/compare/v1.16.0...v1.17.0) (2026-10-04)


### Features

* **infra:** push netdata critical alerts to ntfy and serve public ntfy host ([#243](https://github.com/giocaizzi/rp5-homeserver/issues/243)) ([253aceb](https://github.com/giocaizzi/rp5-homeserver/commit/253aceb77903b77fd5527129e7fcdb8ac840d97e))

## [1.16.0](https://github.com/giocaizzi/rp5-homeserver/compare/v1.15.7...v1.16.0) (2026-10-03)


### Features

* **repo:** materialise infra secrets from bitwarden secrets manager ([#230](https://github.com/giocaizzi/rp5-homeserver/issues/230)) ([165c13f](https://github.com/giocaizzi/rp5-homeserver/commit/165c13fadae793e8b3803d05906f9d015d6ae530))


### Bug Fixes

* **infra:** trim netdata collectors and tune nginx/homepage ([#229](https://github.com/giocaizzi/rp5-homeserver/issues/229)) ([5d746f3](https://github.com/giocaizzi/rp5-homeserver/commit/5d746f34afd35430c804ce85f693d6ae42e820b0))

## [1.15.7](https://github.com/giocaizzi/rp5-homeserver/compare/v1.15.6...v1.15.7) (2026-10-03)


### Bug Fixes

* **infra:** raise netdata memory limit to 1280M ([#222](https://github.com/giocaizzi/rp5-homeserver/issues/222)) ([807265c](https://github.com/giocaizzi/rp5-homeserver/commit/807265c8e8e23f3fb9b523ae7293135e81fbff91))

## [1.15.6](https://github.com/giocaizzi/rp5-homeserver/compare/v1.15.5...v1.15.6) (2026-10-03)


### Bug Fixes

* **infra:** restore homepage after VERSION gained a trailing newline ([#212](https://github.com/giocaizzi/rp5-homeserver/issues/212)) ([ce9c667](https://github.com/giocaizzi/rp5-homeserver/commit/ce9c6671ebfd42b54b6992e660be479a8bff26b3))

## [1.15.5](https://github.com/giocaizzi/rp5-homeserver/compare/v1.15.4...v1.15.5) (2026-10-03)


### Bug Fixes

* **infra:** pin floating images to major tags ([#185](https://github.com/giocaizzi/rp5-homeserver/issues/185)) ([#207](https://github.com/giocaizzi/rp5-homeserver/issues/207)) ([4038029](https://github.com/giocaizzi/rp5-homeserver/commit/403802904ecd1f1c496a78ac50544c802f4ff428))


### Documentation

* **repo:** update add-a-service guide ([#5](https://github.com/giocaizzi/rp5-homeserver/issues/5)) ([#203](https://github.com/giocaizzi/rp5-homeserver/issues/203)) ([cd9eca5](https://github.com/giocaizzi/rp5-homeserver/commit/cd9eca57dbf330c86e00863093dd05c8b68a00cb))

## [1.15.4](https://github.com/giocaizzi/rp5-homeserver/compare/v1.15.3...v1.15.4) (2026-10-03)


### Bug Fixes

* **infra:** raise netdata memory limit to 1024M ([#197](https://github.com/giocaizzi/rp5-homeserver/issues/197)) ([2bb2437](https://github.com/giocaizzi/rp5-homeserver/commit/2bb2437be2fd1fad35eaaf9175f1132d220a7362))

## [1.15.3](https://github.com/giocaizzi/rp5-homeserver/compare/v1.15.2...v1.15.3) (2026-09-27)


### Bug Fixes

* **infra:** pin homepage image to the v2 major tag ([#186](https://github.com/giocaizzi/rp5-homeserver/issues/186)) ([240583b](https://github.com/giocaizzi/rp5-homeserver/commit/240583bc9fd42ab95102fb401170ffc786b2231a))

## [1.15.2](https://github.com/giocaizzi/rp5-homeserver/compare/v1.15.1...v1.15.2) (2026-09-27)


### Bug Fixes

* **infra:** stop rate-limiting Twenty CRM asset chunks ([#177](https://github.com/giocaizzi/rp5-homeserver/issues/177)) ([b3254dd](https://github.com/giocaizzi/rp5-homeserver/commit/b3254dd5ebe6ef3b1cdb7eeca5f06293bc7afc15))

## [1.15.1](https://github.com/giocaizzi/rp5-homeserver/compare/v1.15.0...v1.15.1) (2026-09-27)


### Bug Fixes

* **infra:** point homepage healthcheck at 127.0.0.1/api/healthcheck ([#175](https://github.com/giocaizzi/rp5-homeserver/issues/175)) ([e7b2265](https://github.com/giocaizzi/rp5-homeserver/commit/e7b2265cfb1337ddc526ae8b209706b3a25d35ef))

## [1.15.0](https://github.com/giocaizzi/rp5-homeserver/compare/v1.14.0...v1.15.0) (2026-09-27)


### Features

* **infra:** route crm.<domain> to Twenty CRM ([#168](https://github.com/giocaizzi/rp5-homeserver/issues/168)) ([24b2aa0](https://github.com/giocaizzi/rp5-homeserver/commit/24b2aa09812b84790c8aa882f8de86fcbae070d1))

## [1.14.0](https://github.com/giocaizzi/rp5-homeserver/compare/v1.13.0...v1.14.0) (2026-06-24)


### Features

* **code:** remote Claude Code dev environment (CloudCLI) ([#149](https://github.com/giocaizzi/rp5-homeserver/issues/149)) ([dbce3ac](https://github.com/giocaizzi/rp5-homeserver/commit/dbce3ac1df062063856db600f35d004246b53702))
