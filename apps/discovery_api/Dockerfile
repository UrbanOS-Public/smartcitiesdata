FROM bitwalker/alpine-elixir:1.7.2 as builder
ENV MIX_ENV test
RUN apk update \
    && apk add --no-cache alpine-sdk \
    && rm -rf /var/cache/**/*
COPY . /app
WORKDIR /app
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix test
RUN MIX_ENV=prod mix release

FROM alpine:3.8
RUN apk update \
    && apk add --no-cache bash openssl \
    && rm -rf /var/cache/**/*
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/discovery_api/ .
ENV PORT 80
EXPOSE 80
CMD ["bin/discovery_api", "foreground"]
