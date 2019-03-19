FROM bitwalker/alpine-elixir:1.7.2 as builder
ENV MIX_ENV test
RUN apk update && \
    apk --no-cache --update upgrade alpine-sdk && \
    apk --no-cache add alpine-sdk && \
    rm -rf /var/cache/**/*
COPY . /app
WORKDIR /app
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix format --check-formatted && \
    mix credo && \
    mix test
RUN MIX_ENV=prod mix release

FROM alpine:3.8
ENV COTA_DATA_TOPIC "cota-vehicle-positions"
ENV REPLACE_OS_VARS=true
RUN apk update && \
    apk add --no-cache bash openssl && \
    rm -rf /var/cache/**/*
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/cota_streaming_consumer/ .
ENV PORT 4000
EXPOSE ${PORT}
CMD ["bin/cota_streaming_consumer", "foreground"]
