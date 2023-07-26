FROM golang:alpine AS builder
WORKDIR /app

#Install GO and Tailscale DERPER
RUN apk add go --repository=https://mirrors.aliyun.com/alpine/edge/community
RUN go env -w GO111MODULE=on
RUN go env -w GOPROXY=https://goproxy.cn
RUN go install tailscale.com/cmd/derper@main

FROM alpine:latest

LABEL org.opencontainers.image.source https://github.com/tijjjy/Tailscale-DERP-Docker

#Install Tailscale and requirements
RUN apk add --no-cache curl iptables iproute2

#Install Tailscale and Tailscaled
RUN apk add tailscale --repository=https://mirrors.aliyun.com/alpine/edge/community

COPY --from=builder /go/bin/derper /root/go/bin/derper

#Copy init script
COPY init.sh /init.sh
RUN chmod +x /init.sh

ENTRYPOINT /init.sh
