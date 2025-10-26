# Nginx 


## Snippets Explained

### `ssl-params.conf`
Contains SSL certificate paths and TLS protocol configuration. Used by all HTTPS server blocks.

### `proxy-headers.conf`
Standard proxy headers forwarding client information to upstream services:
- Host header
- Real IP address
- X-Forwarded-For chain
- X-Forwarded-Proto (http/https)

### `websocket-support.conf`
Enables WebSocket support for real-time services (Portainer, N8N, Netdata, Homepage, Backrest).

### `static-assets.conf`
Configures caching and rate limiting for static files (CSS, JS, images, fonts).
