FROM hexpm/elixir:1.14.4-erlang-25.3.2-alpine-3.18.0
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

# TODO: State of Michigan internal CA cert (for reaper ingestion sources like
# mdotatms.state.mi.us that chain to an internal/private CA). Once the .crt
# file is obtained, add it here the same way as the RDS cert above:
#
#   COPY path/to/state-of-michigan-ca.crt /usr/local/share/ca-certificates/
#   RUN update-ca-certificates
#
# No further code changes needed -- reaper's Downloader and andi's UrlTest
# already read CA_CERTFILE_PATH (/etc/ssl/certs/ca-certificates.crt, which
# `update-ca-certificates` rebuilds from everything in the directory above)
# and pass it as their TLS trust bundle.

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get
