# Changelog

## [0.2.8](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.7...firefly-v0.2.8) (2026-10-15)


### Bug Fixes

* **firefly:** stop tasks cleanly instead of SIGKILL on update ([#367](https://github.com/giocaizzi/rp5-homeserver/issues/367)) ([3863c70](https://github.com/giocaizzi/rp5-homeserver/commit/3863c701724947315501318e9d23ebc5b87b1b5a))

## [0.2.7](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.6...firefly-v0.2.7) (2026-10-12)


### Bug Fixes

* **firefly:** keep cron and auto-import secrets out of access logs ([#353](https://github.com/giocaizzi/rp5-homeserver/issues/353)) ([8157e96](https://github.com/giocaizzi/rp5-homeserver/commit/8157e9631f29cd1e004f4b674ce5cec35fe815e4))

## [0.2.6](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.5...firefly-v0.2.6) (2026-10-12)


### Bug Fixes

* **firefly:** keep secrets out of the scheduler's cron entries and log ([#349](https://github.com/giocaizzi/rp5-homeserver/issues/349)) ([d35d03c](https://github.com/giocaizzi/rp5-homeserver/commit/d35d03c478e1fdc953523b830d147caa8c000bb0))

## [0.2.5](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.4...firefly-v0.2.5) (2026-10-12)


### Code Refactoring

* **firefly:** read reconcile account ids from the stack env ([#345](https://github.com/giocaizzi/rp5-homeserver/issues/345)) ([ad2381c](https://github.com/giocaizzi/rp5-homeserver/commit/ad2381c5476f5a76adb03c6660787e1ccdbf4ce1))

## [0.2.4](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.3...firefly-v0.2.4) (2026-10-12)


### Code Refactoring

* **repo:** read the public domain from the stack env in service stacks ([#337](https://github.com/giocaizzi/rp5-homeserver/issues/337)) ([0919adb](https://github.com/giocaizzi/rp5-homeserver/commit/0919adb1fb181b882be843d56194d9e340685910))

## [0.2.3](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.2...firefly-v0.2.3) (2026-10-11)


### Bug Fixes

* **firefly:** stop scheduler, app and importer cleanly on update ([#320](https://github.com/giocaizzi/rp5-homeserver/issues/320)) ([33d23f0](https://github.com/giocaizzi/rp5-homeserver/commit/33d23f0a68a883d273466c0668156d6a6eefb5d3)), closes [#316](https://github.com/giocaizzi/rp5-homeserver/issues/316)

## [0.2.2](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.1...firefly-v0.2.2) (2026-10-11)


### Bug Fixes

* **firefly:** disable db-exporter collectors lacking privileges ([#281](https://github.com/giocaizzi/rp5-homeserver/issues/281)) ([2f231c0](https://github.com/giocaizzi/rp5-homeserver/commit/2f231c0f4755f0f5ea08aa994282d03968ae38b0))
* **firefly:** ignore duplicate errors in scheduled importer runs ([#302](https://github.com/giocaizzi/rp5-homeserver/issues/302)) ([c9a2cfc](https://github.com/giocaizzi/rp5-homeserver/commit/c9a2cfc14295bc3890e3b369268a801d6937c30a))

## [0.2.1](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.0...firefly-v0.2.1) (2026-10-03)


### Bug Fixes

* **firefly:** tune mariadb, php-fpm and scheduler for enforced memory limits ([#228](https://github.com/giocaizzi/rp5-homeserver/issues/228)) ([ca2fa11](https://github.com/giocaizzi/rp5-homeserver/commit/ca2fa11854d08b394cb8b99df58d7b77253f2cca))

## [0.2.0](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.1.3...firefly-v0.2.0) (2026-10-03)


### Features

* **repo:** read swarm secrets from bitwarden secrets manager ([#218](https://github.com/giocaizzi/rp5-homeserver/issues/218)) ([db3fdaf](https://github.com/giocaizzi/rp5-homeserver/commit/db3fdafb41086da35727aadb3cdb2a85197c17c2))


### Bug Fixes

* **firefly:** raise app and importer memory limits ([#223](https://github.com/giocaizzi/rp5-homeserver/issues/223)) ([9c94eae](https://github.com/giocaizzi/rp5-homeserver/commit/9c94eaead084f7ea4bf600bba2d311f734f1ad81))

## [0.1.3](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.1.2...firefly-v0.1.3) (2026-10-03)


### Bug Fixes

* **firefly:** pin floating images to major tags ([#185](https://github.com/giocaizzi/rp5-homeserver/issues/185)) ([#208](https://github.com/giocaizzi/rp5-homeserver/issues/208)) ([464d4f7](https://github.com/giocaizzi/rp5-homeserver/commit/464d4f7fe259b4c9423df23cb2a4c1b8a5bc3e9b))

## [0.1.2](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.1.1...firefly-v0.1.2) (2026-10-03)


### Bug Fixes

* **firefly:** stop logging access token and use /health for readiness ([#198](https://github.com/giocaizzi/rp5-homeserver/issues/198)) ([de2c802](https://github.com/giocaizzi/rp5-homeserver/commit/de2c80223554e8ce33cf777f8ff1269ee6543794))

## [0.1.1](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.1.0...firefly-v0.1.1) (2026-10-03)


### Bug Fixes

* **firefly:** roll tasks on release so bind-mounted scripts update ([#192](https://github.com/giocaizzi/rp5-homeserver/issues/192)) ([3c1abd3](https://github.com/giocaizzi/rp5-homeserver/commit/3c1abd35efa15e40cf676fc4026e20b60dcae834))
