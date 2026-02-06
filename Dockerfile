FROM alpine:3.23 AS base

RUN apk add --no-cache yq

FROM base AS builder

RUN apk add --no-cache bash

FROM base AS runner

RUN apk add --no-cache autossh && \
    apk add --no-cache openssh-client && \
    apk update && \
    apk upgrade openssh-client autossh && \