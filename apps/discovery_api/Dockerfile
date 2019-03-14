FROM bitwalker/alpine-elixir:1.8.1 as builder
ARG HEX_TOKEN
ENV MIX_ENV test
RUN apk update && \
    apk add --no-cache alpine-sdk && \
    rm -rf /var/cache/**/*
COPY . /app
WORKDIR /app
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.organization auth smartcolumbus_os --key ${HEX_TOKEN} && \
    mix deps.get && \
    mix format --check-formatted && \
    mix credo && \
    mix test

RUN MIX_ENV=prod mix release

FROM alpine:3.9
RUN apk update && \
    apk add --no-cache bash openssl && \
    rm -rf /var/cache/**/*
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/discovery_api/ .
ENV PORT 80
EXPOSE 80
CMD ["bin/discovery_api", "foreground"]
