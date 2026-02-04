FROM alpine:3.23

RUN apk add --no-cache autossh && \
    apk add --no-cache openssh-client && \
    apk update && \
    apk upgrade openssh-client autossh && \
    apk add --no-cache yq