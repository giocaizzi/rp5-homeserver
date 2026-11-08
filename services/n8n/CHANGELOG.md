# Changelog

## [0.3.0](https://github.com/giocaizzi/rp5-homeserver/compare/n8n-v0.2.0...n8n-v0.3.0) (2026-11-08)


### Features

* **n8n:** switch to shared postgresql database ([#578](https://github.com/giocaizzi/rp5-homeserver/issues/578)) ([e812e92](https://github.com/giocaizzi/rp5-homeserver/commit/e812e92c8cfc1ba46d7b7f38e21278879f5c387d))


### Performance Improvements

* **n8n:** clamp node heap size to 384mb ([#574](https://github.com/giocaizzi/rp5-homeserver/issues/574)) ([b265ae8](https://github.com/giocaizzi/rp5-homeserver/commit/b265ae8d21babb81c723e1c04b1fac402045712d))

## [0.2.0](https://github.com/giocaizzi/rp5-homeserver/compare/n8n-v0.1.5...n8n-v0.2.0) (2026-11-06)


### Features

* **n8n:** export workflow traces over OTLP to the collector ([#565](https://github.com/giocaizzi/rp5-homeserver/issues/565)) ([24efdcf](https://github.com/giocaizzi/rp5-homeserver/commit/24efdcf6d89314501b34e2e91b2bf29295a1fa42))

## [0.1.5](https://github.com/giocaizzi/rp5-homeserver/compare/n8n-v0.1.4...n8n-v0.1.5) (2026-10-12)


### Code Refactoring

* **repo:** read the public domain from the stack env in service stacks ([#337](https://github.com/giocaizzi/rp5-homeserver/issues/337)) ([0919adb](https://github.com/giocaizzi/rp5-homeserver/commit/0919adb1fb181b882be843d56194d9e340685910))

## [0.1.4](https://github.com/giocaizzi/rp5-homeserver/compare/n8n-v0.1.3...n8n-v0.1.4) (2026-10-11)


### Bug Fixes

* **n8n:** disable diagnostics to stop ECONNREFUSED 0.0.0.0:443 ([#282](https://github.com/giocaizzi/rp5-homeserver/issues/282)) ([ac9563b](https://github.com/giocaizzi/rp5-homeserver/commit/ac9563b3d56ea10f7d86d3dacfd8448307544691))

## [0.1.3](https://github.com/giocaizzi/rp5-homeserver/compare/n8n-v0.1.2...n8n-v0.1.3) (2026-10-03)


### Bug Fixes

* **n8n:** bound heap and runner memory and tune postgres ([#226](https://github.com/giocaizzi/rp5-homeserver/issues/226)) ([48738de](https://github.com/giocaizzi/rp5-homeserver/commit/48738dee3f368987e51f5e41a5b9972b8f9f0f42))

## [0.1.2](https://github.com/giocaizzi/rp5-homeserver/compare/n8n-v0.1.1...n8n-v0.1.2) (2026-10-03)


### Bug Fixes

* **n8n:** raise app memory limit to 1536M ([#221](https://github.com/giocaizzi/rp5-homeserver/issues/221)) ([cf0216b](https://github.com/giocaizzi/rp5-homeserver/commit/cf0216bea9d621ac11332df1c5b5cabc679c951e))

## [0.1.1](https://github.com/giocaizzi/rp5-homeserver/compare/n8n-v0.1.0...n8n-v0.1.1) (2026-10-03)


### Bug Fixes

* **n8n:** raise app memory limit to 1280M ([#195](https://github.com/giocaizzi/rp5-homeserver/issues/195)) ([a78cf50](https://github.com/giocaizzi/rp5-homeserver/commit/a78cf5016f9a3bca88a6e8a6d7cc7b51f6b23682))
