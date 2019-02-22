FROM bitwalker/alpine-elixir:1.8.0 as builder
ENV MIX_ENV=test
RUN apk update \
    && apk add --no-cache alpine-sdk \
    && rm -rf /var/cache/**/*
COPY . /app
WORKDIR /app
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix test && \
    mix credo

RUN MIX_ENV=prod mix release

FROM alpine:3.8
ENV REPLACE_OS_VARS=true
RUN apk update \
    && apk add --no-cache bash openssl \
    && rm -rf /var/cache/**/*
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/reaper/ .
CMD ["bin/reaper", "foreground"]
