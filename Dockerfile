FROM hexpm/elixir:1.10.4-erlang-23.2.7.5-alpine-3.16.0
ARG app_name
COPY . /app
WORKDIR /app
ENV NPM_CONFIG_UNSAFE_PERM true
RUN apk upgrade && apk update && \
    apk --no-cache --update upgrade alpine-sdk && \
    apk --no-cache add alpine-sdk && \
    apk --no-cache --update add \
      make \
      g++ \
      wget \
      ca-certificates \
      curl \
      inotify-tools \
      nodejs \
      npm && \
      npm install npm@8.10.0 -g --no-progress && \
    rm -rf /var/cache/**/*

RUN curl -L \
    -o /usr/local/share/ca-certificates/rds-ca-2019-root.crt \
    https://s3.amazonaws.com/rds-downloads/rds-ca-2019-root.pem \
    && update-ca-certificates

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get
