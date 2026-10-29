# syntax=docker/dockerfile:1

FROM golang:1.25.5-alpine3.23 AS builder
WORKDIR /src
COPY go.mod go.sum ./
COPY fritzbox_lua ./fritzbox_lua
COPY fritzbox_upnp ./fritzbox_upnp
COPY main.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/fritzbox_exporter .

FROM alpine:3.23 AS runtime-image

ARG REPO=odcheck/fritzbox_exporter
LABEL org.opencontainers.image.source=https://github.com/${REPO}

ENV USERNAME=username \
    PASSWORD=password \
    GATEWAY_URL=http://fritz.box:49000 \
    GATEWAY_LUAURL=http://fritz.box \
    LISTEN_ADDRESS=0.0.0.0:9042

RUN mkdir /app \
    && addgroup -S -g 1000 fritzbox \
    && adduser -S -u 1000 -G fritzbox fritzbox \
    && chown -R fritzbox:fritzbox /app

WORKDIR /app
COPY --chown=fritzbox:fritzbox --from=builder /out/fritzbox_exporter /app/fritzbox_exporter
# Default metric defs (Compose may bind-mount overrides over these paths).
COPY --chown=fritzbox:fritzbox metrics.json metrics-lua.json /app/

EXPOSE 9042
USER fritzbox
ENTRYPOINT [ "sh", "-c", "exec /app/fritzbox_exporter -username \"$USERNAME\" -password \"$PASSWORD\" -gateway-url \"$GATEWAY_URL\" -gateway-luaurl \"$GATEWAY_LUAURL\" -listen-address \"$LISTEN_ADDRESS\"" ]
