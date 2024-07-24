#
# 1. Build Container
#
FROM golang:1.20-alpine AS build

ARG DEBUG=false 
ARG APP_NAME=iohub-stories
ENV GO111MODULE=auto \
    GOOS=linux \
    GOARCH=amd64 \
    DEBUG=${DEBUG} \
    APP_NAME=${APP_NAME}

RUN apk update && apk upgrade && \
    apk --update add libc-dev git gcc libgcc make && \
    mkdir -p /src

# First add modules list to better utilize caching
COPY go.sum go.mod /src/

WORKDIR /src

# Download dependencies
RUN go mod download && go install github.com/go-delve/delve/cmd/dlv@latest

COPY . .

# Build components.
# Put built binaries and runtime resources in /app dir ready to be copied over or used.
RUN if [ "$DEBUG" = "true" ]; then make debug; else make install; fi; \
    mkdir -p /app/res && mkdir /app/sql && cp /src/${APP_NAME} /app/ && \
    cp -r /src/docker /src/config.yml /app/ && cp -r /src/res/ /app/res && \
    cp -r /src/sql /app/sql

#
# 2. Runtime Container
#
FROM alpine

LABEL maintainer="Dwiki Prayudia <dwikiprayudia@gmail.com> KLOC"

ARG DEBUG=false 
ARG DEBUG_PORT=40000
ARG APP_NAME=iohub-stories
ENV APP_NAME=${APP_NAME} \
    DEBUG=${DEBUG} \
    DEBUG_PORT=${DEBUG_PORT}\
    TZ=Asia/Jakarta \
    PATH="/app:${PATH}" 

RUN apk add --update --no-cache \
    busybox-extras \
    tzdata \
    ca-certificates \
    bash \
    curl && \
    apk upgrade && \
    cp --remove-destination /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone

RUN mkdir -p /app/res && mkdir /lib64 && ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2

WORKDIR /app

COPY --from=build /app/res/ \
                  /app/sql/ \
                  /app/${APP_NAME} \
                  /app/config.yml \
                  /app/docker/entrypoint.sh \
                  /app/docker/wait-for-it.sh \
                  /go/bin/dlv /app/

RUN chmod +x /app/*.sh

EXPOSE 9001 ${DEBUG_PORT}

ENTRYPOINT entrypoint.sh --app ${APP_NAME} --debug ${DEBUG} --debug-port ${DEBUG_PORT}
