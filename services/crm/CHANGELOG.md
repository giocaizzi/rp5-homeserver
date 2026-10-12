# Changelog

## [0.2.4](https://github.com/giocaizzi/rp5-homeserver/compare/crm-v0.2.3...crm-v0.2.4) (2026-10-12)


### Code Refactoring

* **cloud:** give the crm api service token a generic name ([#336](https://github.com/giocaizzi/rp5-homeserver/issues/336)) ([6e7f131](https://github.com/giocaizzi/rp5-homeserver/commit/6e7f1312ce8642b8af854ccc10d4588991e8e4b2))
* **repo:** read the public domain from the stack env in service stacks ([#337](https://github.com/giocaizzi/rp5-homeserver/issues/337)) ([56f387a](https://github.com/giocaizzi/rp5-homeserver/commit/56f387af39ba8012fb18708f5ba874eb6d327818))

## [0.2.3](https://github.com/giocaizzi/rp5-homeserver/compare/crm-v0.2.2...crm-v0.2.3) (2026-10-11)


### Bug Fixes

* **crm:** scrape crm-redis and alert on missing redis metrics ([#287](https://github.com/giocaizzi/rp5-homeserver/issues/287)) ([a24364c](https://github.com/giocaizzi/rp5-homeserver/commit/a24364c91b1f73e1d1ddbf939bc01d6ab7918194))

## [0.2.2](https://github.com/giocaizzi/rp5-homeserver/compare/crm-v0.2.1...crm-v0.2.2) (2026-10-03)


### Bug Fixes

* **crm:** run worker without yarn wrappers and bound postgres/redis memory ([#227](https://github.com/giocaizzi/rp5-homeserver/issues/227)) ([117ac7d](https://github.com/giocaizzi/rp5-homeserver/commit/117ac7d13dde936c6856b92a4874825bc56c52e7))

## [0.2.1](https://github.com/giocaizzi/rp5-homeserver/compare/crm-v0.2.0...crm-v0.2.1) (2026-10-03)


### Bug Fixes

* **crm:** raise server and worker memory limits to 1536M ([#216](https://github.com/giocaizzi/rp5-homeserver/issues/216)) ([a4e0f4f](https://github.com/giocaizzi/rp5-homeserver/commit/a4e0f4f9b35fe551e80a6a5c95709e6a94bc0782))

## [0.2.0](https://github.com/giocaizzi/rp5-homeserver/compare/crm-v0.1.0...crm-v0.2.0) (2026-09-27)


### Features

* **crm:** add Twenty CRM stack ([#167](https://github.com/giocaizzi/rp5-homeserver/issues/167)) ([04d7e2e](https://github.com/giocaizzi/rp5-homeserver/commit/04d7e2e2c7381dd9c2cc3f0c911bca4e2f035f3b))


### Bug Fixes

* **crm:** raise worker heap to 768M ([#174](https://github.com/giocaizzi/rp5-homeserver/issues/174)) ([819dce1](https://github.com/giocaizzi/rp5-homeserver/commit/819dce127d9bafa41d0ac08b20ce2fd6d74884c5))
