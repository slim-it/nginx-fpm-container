# nginx-fpm-container

Unprivileged nginx image for running in the same pod as a PHP-FPM application
container. It owns the nginx/PHP-FPM transport and the safe common server
shell; each application mounts only the routing rules specific to that
application.

The two containers share their network namespace, so PHP-FPM must listen on
`127.0.0.1:9000`. They also share the application tree at `/var/www/html`:
PHP or an init container fills it, while nginx mounts it read-only and serves
static files directly. nginx listens unprivileged on port `8080`.
Its separate health listener uses port `18080`; the application Service does
not expose that port.

## Configuration contract

The image provides:

- `/etc/nginx/conf.d/default.conf` — the application server on port 8080, with
  relative generated redirects, dotfile denial and the application-rule
  include, plus an nginx-only `/healthz` endpoint on port 18080 that is not
  exposed by the application's Service;
- `/etc/nginx/snippets/php-fpm.conf` — the FastCGI parameters and loopback
  upstream, with `SERVER_NAME` set to the request's host, and the public
  request scheme and standard port restored from `X-Forwarded-Proto` when the
  sidecar runs behind a trusted proxy;
- `/etc/nginx/snippets/php-files.conf` — an optional conventional `*.php`
  location that checks the script exists before passing it to PHP-FPM.

The application supplies one or more `*.conf` files under
`/etc/nginx/app.d/`. A conventional application needs only its own limits and
access rules plus:

```nginx
include /etc/nginx/snippets/php-files.conf;
```

An application with a front controller or another routing model includes
`php-fpm.conf` from its own locations and sets `SCRIPT_FILENAME` and any other
FastCGI parameters there.

The sidecar accepts `X-Forwarded-Proto` as authoritative because its normal
caller is a trusted ingress that replaces the inbound value. Without that
header, direct traffic retains nginx's own scheme and listener port.

The application server is a catch-all whose own `server_name` names no host, so
PHP receives the request's host as `SERVER_NAME`. Behind that ingress it is one
of the hostnames the application is routed for — the value PHP already sees as
`HTTP_HOST`. An application that restricts its hostnames still checks it.

The image deliberately does not provide application profiles or select a
document root. The root, upload limits, protected paths, front-controller
rewrites and timeouts are application policy and stay in the consuming
repository.

## Versioning

`VERSION` is the single source of truth for the complete upstream
`nginxinc/nginx-unprivileged` base-image tag. Renovate updates it only along
nginx's stable release branches.

CI publishes a tag formed from the upstream nginx version, the workflow build
number, and the upstream image variant. The build number makes every rebuild
strictly newer even when only this repository's configuration changes. The
exact upstream tag is also recorded in the image's
`nl.slim-it.nginx.base-tag` label.

## Image

CI publishes:

```text
ghcr.io/slim-it/nginx-fpm-container:<nginx-version>.<build>-alpine
ghcr.io/slim-it/nginx-fpm-container:latest
ghcr.io/slim-it/nginx-fpm-container:sha-<git-sha>
```

The build runs `nginx -t` with a representative application rules file, so it
parses the server shell and both reusable snippets together before publishing.

## Build locally

```sh
docker build \
  --build-arg NGINX_BASE_TAG="$(cat VERSION)" \
  -t ghcr.io/slim-it/nginx-fpm-container:local .
```

## Run locally

Run the image in a pod or another shared network namespace with PHP-FPM, mount
the shared application tree read-only at `/var/www/html`, and mount the
application rules read-only under `/etc/nginx/app.d/`. For example:

```sh
podman pod create --name php-app -p 8080:8080
podman volume create php-app-www
podman run -d --pod php-app -v php-app-www:/var/www/html php:8-fpm-alpine
podman run -d --pod php-app \
  -v php-app-www:/var/www/html:ro \
  -v ./rules.conf:/etc/nginx/app.d/rules.conf:ro \
  ghcr.io/slim-it/nginx-fpm-container:local
```
