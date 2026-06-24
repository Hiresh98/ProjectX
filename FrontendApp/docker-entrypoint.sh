#!/bin/sh
set -eu

# Where the browser-facing nginx should forward /api/* requests.
#  - docker compose : the compose service name resolves via the embedded DNS
#  - kubernetes     : override with the in-cluster FQDN (see k8s/frontend.yaml)
export BACKEND_ORIGIN="${BACKEND_ORIGIN:-http://backend:4000}"

# nginx's `resolver` directive ignores /etc/resolv.conf, so pull the first
# nameserver from it. Works for both Docker (127.0.0.11) and Kubernetes (kube-dns).
NAMESERVER="$(awk '/^nameserver/ { print $2; exit }' /etc/resolv.conf)"
export NAMESERVER="${NAMESERVER:-127.0.0.11}"

envsubst '${BACKEND_ORIGIN} ${NAMESERVER}' \
    < /etc/nginx/templates/default.conf.template \
    > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
