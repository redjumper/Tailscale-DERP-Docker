FROM golang:alpine AS builder
WORKDIR /app

#Install GO and Tailscale DERPER
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories
RUN apk update && apk add go
#RUN go env -w GO111MODULE=on
#RUN go env -w GOPROXY=https://goproxy.cn
RUN go install tailscale.com/cmd/derper@main

FROM alpine:latest

LABEL org.opencontainers.image.source https://github.com/tijjjy/Tailscale-DERP-Docker

#Install Tailscale and requirements
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories
RUN apk update && apk add curl iptables iproute2
#Install Tailscale and Tailscaled
RUN apk add tailscale

COPY --from=builder /go/bin/derper /root/go/bin/derper

#Copy init script
COPY init.sh /init.sh
RUN chmod +x /init.sh

ENTRYPOINT /init.sh
