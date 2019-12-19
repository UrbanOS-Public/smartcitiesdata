FROM bitwalker/alpine-elixir:1.8.1
ARG app_name
COPY . /app
WORKDIR /app
ENV NPM_CONFIG_UNSAFE_PERM true
RUN apk update && \
    apk --no-cache --update upgrade alpine-sdk && \
    apk --no-cache add alpine-sdk && \
    apk --no-cache --update add \
      make \
      g++ \
      wget \
      curl \
      inotify-tools \
      nodejs \
      nodejs-npm && \
      npm install npm -g --no-progress && \
    rm -rf /var/cache/**/*
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get