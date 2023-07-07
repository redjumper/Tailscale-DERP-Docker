FROM alpine:latest

LABEL org.opencontainers.image.source https://github.com/tijjjy/Tailscale-DERP-Docker

#Install Tailscale and requirements
RUN apk add curl iptables iproute2

#Install GO and Tailscale DERPER
RUN apk add go --repository=https://mirrors.aliyun.com/alpine/edge/community
RUN go env -w GO111MODULE=on
RUN go env -w GOPROXY=https://goproxy.cn
RUN go install tailscale.com/cmd/derper@main

#Install Tailscale and Tailscaled
RUN apk add tailscale --repository=https://mirrors.aliyun.com/alpine/edge/community

#Copy init script
COPY init.sh /init.sh
RUN chmod +x /init.sh

#Derper Web Ports
EXPOSE 80
EXPOSE 443/tcp
#STUN
EXPOSE 3478/udp

ENTRYPOINT /init.sh
