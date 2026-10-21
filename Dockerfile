ARG NGINX_BASE_TAG
FROM nginxinc/nginx-unprivileged:${NGINX_BASE_TAG}

ARG NGINX_BASE_TAG
LABEL org.opencontainers.image.title="nginx PHP-FPM container"
LABEL org.opencontainers.image.description="Unprivileged nginx sidecar for PHP-FPM application containers"
LABEL org.opencontainers.image.source="https://github.com/slim-it/nginx-fpm-container"
LABEL org.opencontainers.image.base.name="docker.io/nginxinc/nginx-unprivileged:${NGINX_BASE_TAG}"
# Not org.opencontainers.image.version: CI overwrites that annotation with the
# published image tag.
LABEL nl.slim-it.nginx.base-tag="${NGINX_BASE_TAG}"

COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY nginx/snippets/ /etc/nginx/snippets/

# Validate the complete contract, not only the always-loaded server shell: the
# fixture opts into the reusable PHP location and thereby parses both snippets.
USER root
COPY tests/rules.conf /etc/nginx/app.d/zz-build-test.conf
RUN nginx -t \
    && rm /etc/nginx/app.d/zz-build-test.conf /tmp/nginx.pid

# Numeric, so a runtime that requires a non-root user can verify it.
USER 101:101
