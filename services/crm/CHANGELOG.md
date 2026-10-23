# Changelog

## [0.3.1](https://github.com/giocaizzi/rp5-homeserver/compare/crm-v0.3.0...crm-v0.3.1) (2026-10-23)


### Bug Fixes

* **crm:** bump Twenty to v2.51.0 ([#511](https://github.com/giocaizzi/rp5-homeserver/issues/511)) ([d651ae2](https://github.com/giocaizzi/rp5-homeserver/commit/d651ae2a728478af2b715b88c693a8c34209dacf))

## [0.3.0](https://github.com/giocaizzi/rp5-homeserver/compare/crm-v0.2.5...crm-v0.3.0) (2026-10-15)


### Features

* **cloud:** allow per-user oauth for crm mcp ([#375](https://github.com/giocaizzi/rp5-homeserver/issues/375)) ([c3d0cf6](https://github.com/giocaizzi/rp5-homeserver/commit/c3d0cf664fa8d6654b31af57e58fdf0a69da4bce))

## [0.2.5](https://github.com/giocaizzi/rp5-homeserver/compare/crm-v0.2.4...crm-v0.2.5) (2026-10-15)


### Bug Fixes

* **cloud:** keep crm /graphql under the ui access app ([#371](https://github.com/giocaizzi/rp5-homeserver/issues/371)) ([a379b11](https://github.com/giocaizzi/rp5-homeserver/commit/a379b11913da02c8878edaf90abe697fb37a9748))
* **crm:** log only errors and warnings from twenty ([#370](https://github.com/giocaizzi/rp5-homeserver/issues/370)) ([cf01fd8](https://github.com/giocaizzi/rp5-homeserver/commit/cf01fd8a6c6b2b5b8c5150e97b9e34a10440554a))

## [0.2.4](https://github.com/giocaizzi/rp5-homeserver/compare/crm-v0.2.3...crm-v0.2.4) (2026-10-12)


### Code Refactoring

* **cloud:** give the crm api service token a generic name ([#336](https://github.com/giocaizzi/rp5-homeserver/issues/336)) ([1293b0f](https://github.com/giocaizzi/rp5-homeserver/commit/1293b0fd572e163e72bdfe6b5cc7bdde216026af))
* **repo:** read the public domain from the stack env in service stacks ([#337](https://github.com/giocaizzi/rp5-homeserver/issues/337)) ([0919adb](https://github.com/giocaizzi/rp5-homeserver/commit/0919adb1fb181b882be843d56194d9e340685910))

## [0.2.3](https://github.com/giocaizzi/rp5-homeserver/compare/crm-v0.2.2...crm-v0.2.3) (2026-10-11)


### Bug Fixes

* **crm:** scrape crm-redis and alert on missing redis metrics ([#287](https://github.com/giocaizzi/rp5-homeserver/issues/287)) ([c6cf31a](https://github.com/giocaizzi/rp5-homeserver/commit/c6cf31a25cf3c8cf570dcde0fe0511c5dbd8d67a))

## [0.2.2](https://github.com/giocaizzi/rp5-homeserver/compare/crm-v0.2.1...crm-v0.2.2) (2026-10-03)


### Bug Fixes

* **crm:** run worker without yarn wrappers and bound postgres/redis memory ([#227](https://github.com/giocaizzi/rp5-homeserver/issues/227)) ([4f11b8c](https://github.com/giocaizzi/rp5-homeserver/commit/4f11b8c5b9f76a39d2ff842790c846ce50fb3b25))

## [0.2.1](https://github.com/giocaizzi/rp5-homeserver/compare/crm-v0.2.0...crm-v0.2.1) (2026-10-03)


### Bug Fixes

* **crm:** raise server and worker memory limits to 1536M ([#216](https://github.com/giocaizzi/rp5-homeserver/issues/216)) ([53e54c4](https://github.com/giocaizzi/rp5-homeserver/commit/53e54c463c15bb69acb0e50f92e42578c3f607e2))

## [0.2.0](https://github.com/giocaizzi/rp5-homeserver/compare/crm-v0.1.0...crm-v0.2.0) (2026-09-27)


### Features

* **crm:** add Twenty CRM stack ([#167](https://github.com/giocaizzi/rp5-homeserver/issues/167)) ([2f44223](https://github.com/giocaizzi/rp5-homeserver/commit/2f4422320f7b765d841bbb7a9d9015d382a85b17))


### Bug Fixes

* **crm:** raise worker heap to 768M ([#174](https://github.com/giocaizzi/rp5-homeserver/issues/174)) ([4436fc3](https://github.com/giocaizzi/rp5-homeserver/commit/4436fc3f436599e062f3192378cd383183fd05ba))
