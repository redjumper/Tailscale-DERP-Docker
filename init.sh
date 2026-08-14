#!/bin/sh

set -eu

log() {
    printf '%s\n' "[init] $*"
}

fail() {
    printf '%s\n' "[init] ERROR: $*" >&2
    exit 1
}

: "${TAILSCALE_DERP_HOSTNAME:?TAILSCALE_DERP_HOSTNAME is required}"

TAILSCALE_DERP_ADDR="${TAILSCALE_DERP_ADDR:-:443}"
TAILSCALE_DERP_CERTMODE="${TAILSCALE_DERP_CERTMODE:-letsencrypt}"
TAILSCALE_DERP_STUN_PORT="${TAILSCALE_DERP_STUN_PORT:-3478}"
TAILSCALE_DERP_VERIFY_CLIENTS="${TAILSCALE_DERP_VERIFY_CLIENTS:-true}"

case "$TAILSCALE_DERP_CERTMODE" in
    letsencrypt|manual|gcp) ;;
    *) fail "unsupported TAILSCALE_DERP_CERTMODE: $TAILSCALE_DERP_CERTMODE" ;;
esac

case "$TAILSCALE_DERP_VERIFY_CLIENTS" in
    true|false) ;;
    *) fail 'TAILSCALE_DERP_VERIFY_CLIENTS must be true or false' ;;
esac

cert_dir="/root/derper/$TAILSCALE_DERP_HOSTNAME"
mkdir -p "$cert_dir"

log 'Starting tailscaled.'
tailscaled --state=/var/lib/tailscale/tailscaled.state &
tailscaled_pid=$!

attempt=0
while [ ! -S /var/run/tailscale/tailscaled.sock ]; do
    if ! kill -0 "$tailscaled_pid" 2>/dev/null; then
        wait "$tailscaled_pid" || true
        fail 'tailscaled exited before its control socket became ready'
    fi

    attempt=$((attempt + 1))
    if [ "$attempt" -ge 30 ]; then
        fail 'tailscaled did not become ready within 30s'
    fi
    sleep 1
done

if tailscale status --json 2>/dev/null \
    | grep -Eq '"BackendState"[[:space:]]*:[[:space:]]*"Running"'; then
    log 'Using the existing authenticated Tailscale state.'
else
    : "${TAILSCALE_AUTH_KEY:?TAILSCALE_AUTH_KEY is required for initial login}"

    log 'Authenticating with the Tailscale control server.'
    if [ -n "${TAILSCALE_LOGIN_SERVER:-}" ]; then
        tailscale up \
            --login-server="$TAILSCALE_LOGIN_SERVER" \
            --accept-dns=false \
            --auth-key="$TAILSCALE_AUTH_KEY"
    else
        tailscale up \
            --accept-dns=false \
            --auth-key="$TAILSCALE_AUTH_KEY"
    fi
fi

# Do not pass the reusable login secret to the long-running DERP process.
unset TAILSCALE_AUTH_KEY

log "Starting DERP for $TAILSCALE_DERP_HOSTNAME on $TAILSCALE_DERP_ADDR."
exec derper \
    --hostname="$TAILSCALE_DERP_HOSTNAME" \
    --a="$TAILSCALE_DERP_ADDR" \
    --http-port=-1 \
    --certmode="$TAILSCALE_DERP_CERTMODE" \
    --certdir="$cert_dir" \
    --stun-port="$TAILSCALE_DERP_STUN_PORT" \
    --verify-clients="$TAILSCALE_DERP_VERIFY_CLIENTS"
