FROM bitwalker/alpine-elixir:1.7.2 as builder
ENV MIX_ENV test
RUN apk upgrade && \
    apk --no-cache --update upgrade alpine-sdk && \
    apk --no-cache add alpine-sdk && \
    rm -rf /var/cache/**/*
COPY . /app
WORKDIR /app
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix format --check-formatted && \
RUN MIX_ENV=prod mix release

FROM alpine:3.9
ENV REPLACE_OS_VARS=true
RUN apk upgrade && \
    apk add --no-cache bash openssl && \
    rm -rf /var/cache/**/*
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/discovery_streams/ .
ENV PORT 4000
EXPOSE ${PORT}
CMD ["bin/discovery_streams", "foreground"]
