#!/usr/bin/env sh

#Start tailscaled and connect to tailnet
/usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state >> /dev/stdout &
if [ -n "$TAILSCALE_LOGIN_SERVER" ]; then
  /usr/bin/tailscale up --login-server "$TAILSCALE_LOGIN_SERVER" --accept-dns --auth-key "$TAILSCALE_AUTH_KEY" >> /dev/stdout &
else
  /usr/bin/tailscale up --accept-dns --auth-key "$TAILSCALE_AUTH_KEY" >> /dev/stdout &
fi

#Check for and or create certs directory
if [[ ! -d "/root/derper/$TAILSCALE_DERP_HOSTNAME" ]]
then
    mkdir -p /root/derper/$TAILSCALE_DERP_HOSTNAME
fi

#Start Tailscale derp server
/root/go/bin/derper --hostname=$TAILSCALE_DERP_HOSTNAME -a=$TAILSCALE_DERP_ADDR -http-port=-1 -certmode=$TAILSCALE_DERP_CERTMODE -certdir=/root/derper/$TAILSCALE_DERP_HOSTNAME --stun-port=$TAILSCALE_DERP_STUN_PORT --verify-clients=$TAILSCALE_DERP_VERIFY_CLIENTS
