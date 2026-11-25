# Changelog

## [0.3.0](https://github.com/giocaizzi/rp5-homeserver/compare/greenhouse-v0.2.0...greenhouse-v0.3.0) (2026-11-25)


### ⚠ BREAKING CHANGES

* **greenhouse:** greenhouse stack environment variables in `services/greenhouse/docker-compose.yml` now use the `GREENHOUSE_*` prefix instead of `IRRIGATION_*`.

### Features

* **greenhouse:** rename IRRIGATION_* env vars to GREENHOUSE_* ([#598](https://github.com/giocaizzi/rp5-homeserver/issues/598)) ([a0a2b13](https://github.com/giocaizzi/rp5-homeserver/commit/a0a2b13553574591a455e88c3e26adaa04cc5e9b))

## [0.2.0](https://github.com/giocaizzi/rp5-homeserver/compare/greenhouse-v0.1.0...greenhouse-v0.2.0) (2026-10-13)


### Features

* **greenhouse:** push irrigation runs and alerts to ntfy ([#360](https://github.com/giocaizzi/rp5-homeserver/issues/360)) ([b0f934e](https://github.com/giocaizzi/rp5-homeserver/commit/b0f934ee979108d12fe7e8b7d41a3224056ee457))
