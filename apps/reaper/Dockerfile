FROM bitwalker/alpine-elixir:1.8.1 as builder
COPY . /app
WORKDIR /app
RUN apk upgrade && \
    apk --no-cache --update upgrade alpine-sdk && \
    apk --no-cache add alpine-sdk && \
    rm -rf /var/cache/**/*
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get
RUN MIX_ENV=prod mix release

FROM alpine:3.9
ENV REPLACE_OS_VARS=true
RUN apk upgrade && \
    apk add --no-cache bash openssl && \
    rm -rf /var/cache/**/*
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/reaper/ .
CMD ["bin/reaper", "foreground"]
