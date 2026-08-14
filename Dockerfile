# syntax=docker/dockerfile:1

FROM golang:alpine AS builder

ARG TAILSCALE_VERSION=v1.98.8
ARG GOPROXY=https://goproxy.cn,direct

ENV GOPROXY=${GOPROXY}

# Build all Tailscale components from the same revision. This is required for
# reliable DERP client verification.
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    GOBIN=/out CGO_ENABLED=0 go install \
        "tailscale.com/cmd/derper@${TAILSCALE_VERSION}" \
        "tailscale.com/cmd/tailscale@${TAILSCALE_VERSION}" \
        "tailscale.com/cmd/tailscaled@${TAILSCALE_VERSION}"

FROM alpine:latest

LABEL org.opencontainers.image.source="https://github.com/redjumper/Tailscale-DERP-Docker" \
      org.opencontainers.image.title="Tailscale DERP server"

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' \
        /etc/apk/repositories \
    && apk add --no-cache \
        ca-certificates \
        iproute2 \
        iptables \
        tini \
    && mkdir -p \
        /root/derper \
        /var/lib/tailscale \
        /var/run/tailscale

COPY --from=builder /out/derper /usr/local/bin/derper
COPY --from=builder /out/tailscale /usr/local/bin/tailscale
COPY --from=builder /out/tailscaled /usr/local/bin/tailscaled
COPY --chmod=0755 init.sh /usr/local/bin/init.sh

ENV TAILSCALE_DERP_ADDR=":443" \
    TAILSCALE_DERP_CERTMODE="letsencrypt" \
    TAILSCALE_DERP_STUN_PORT="3478" \
    TAILSCALE_DERP_VERIFY_CLIENTS="true"

EXPOSE 80/tcp 443/tcp 3478/udp

STOPSIGNAL SIGTERM

ENTRYPOINT ["/sbin/tini", "-g", "--", "/usr/local/bin/init.sh"]
