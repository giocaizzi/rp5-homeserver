# Changelog

## [0.2.7](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.6...firefly-v0.2.7) (2026-10-12)


### Bug Fixes

* **firefly:** keep cron and auto-import secrets out of access logs ([#353](https://github.com/giocaizzi/rp5-homeserver/issues/353)) ([9b543db](https://github.com/giocaizzi/rp5-homeserver/commit/9b543dbd66d653beb4d0e235e7303fcfd0b022a3))

## [0.2.6](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.5...firefly-v0.2.6) (2026-10-12)


### Bug Fixes

* **firefly:** keep secrets out of the scheduler's cron entries and log ([#349](https://github.com/giocaizzi/rp5-homeserver/issues/349)) ([3b201de](https://github.com/giocaizzi/rp5-homeserver/commit/3b201deb657e7bedab539b9c6a891338331bd1d3))

## [0.2.5](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.4...firefly-v0.2.5) (2026-10-12)


### Code Refactoring

* **firefly:** read reconcile account ids from the stack env ([#345](https://github.com/giocaizzi/rp5-homeserver/issues/345)) ([14b5ee5](https://github.com/giocaizzi/rp5-homeserver/commit/14b5ee5d154bf004b4fa2e1c7aa508b6cb9b4e47))

## [0.2.4](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.3...firefly-v0.2.4) (2026-10-12)


### Code Refactoring

* **repo:** read the public domain from the stack env in service stacks ([#337](https://github.com/giocaizzi/rp5-homeserver/issues/337)) ([56f387a](https://github.com/giocaizzi/rp5-homeserver/commit/56f387af39ba8012fb18708f5ba874eb6d327818))

## [0.2.3](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.2...firefly-v0.2.3) (2026-10-11)


### Bug Fixes

* **firefly:** stop scheduler, app and importer cleanly on update ([#320](https://github.com/giocaizzi/rp5-homeserver/issues/320)) ([bcd4e38](https://github.com/giocaizzi/rp5-homeserver/commit/bcd4e38869d6994c048ab4bd5beb2cd524e992cb)), closes [#316](https://github.com/giocaizzi/rp5-homeserver/issues/316)

## [0.2.2](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.1...firefly-v0.2.2) (2026-10-11)


### Bug Fixes

* **firefly:** disable db-exporter collectors lacking privileges ([#281](https://github.com/giocaizzi/rp5-homeserver/issues/281)) ([f5a8269](https://github.com/giocaizzi/rp5-homeserver/commit/f5a82697e5797d49e83d63c8a90896f1e21bbffd))
* **firefly:** ignore duplicate errors in scheduled importer runs ([#302](https://github.com/giocaizzi/rp5-homeserver/issues/302)) ([051a11c](https://github.com/giocaizzi/rp5-homeserver/commit/051a11cf05c066dd582a9aaf690c4c266a37db6d))

## [0.2.1](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.2.0...firefly-v0.2.1) (2026-10-03)


### Bug Fixes

* **firefly:** tune mariadb, php-fpm and scheduler for enforced memory limits ([#228](https://github.com/giocaizzi/rp5-homeserver/issues/228)) ([82d1d80](https://github.com/giocaizzi/rp5-homeserver/commit/82d1d80bcf16aa03cf5114f0dbf76e408998a848))

## [0.2.0](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.1.3...firefly-v0.2.0) (2026-10-03)


### Features

* **repo:** read swarm secrets from bitwarden secrets manager ([#218](https://github.com/giocaizzi/rp5-homeserver/issues/218)) ([7de0463](https://github.com/giocaizzi/rp5-homeserver/commit/7de04634c894b5be942d5157cc41c1cc2e659b6c))


### Bug Fixes

* **firefly:** raise app and importer memory limits ([#223](https://github.com/giocaizzi/rp5-homeserver/issues/223)) ([2932233](https://github.com/giocaizzi/rp5-homeserver/commit/293223389e2a80dd7feab3aa1b8da5a4e7fede92))

## [0.1.3](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.1.2...firefly-v0.1.3) (2026-10-03)


### Bug Fixes

* **firefly:** pin floating images to major tags ([#185](https://github.com/giocaizzi/rp5-homeserver/issues/185)) ([#208](https://github.com/giocaizzi/rp5-homeserver/issues/208)) ([96da371](https://github.com/giocaizzi/rp5-homeserver/commit/96da371bf10c3d685083237a326c423958265aa9))

## [0.1.2](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.1.1...firefly-v0.1.2) (2026-10-03)


### Bug Fixes

* **firefly:** stop logging access token and use /health for readiness ([#198](https://github.com/giocaizzi/rp5-homeserver/issues/198)) ([8687b5f](https://github.com/giocaizzi/rp5-homeserver/commit/8687b5f36356ab8f61d1175f0d01bf507626eaf9))

## [0.1.1](https://github.com/giocaizzi/rp5-homeserver/compare/firefly-v0.1.0...firefly-v0.1.1) (2026-10-03)


### Bug Fixes

* **firefly:** roll tasks on release so bind-mounted scripts update ([#192](https://github.com/giocaizzi/rp5-homeserver/issues/192)) ([39859de](https://github.com/giocaizzi/rp5-homeserver/commit/39859dec39ff8b34646548278d57e02f44dea4f4))
