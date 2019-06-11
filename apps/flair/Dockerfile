FROM bitwalker/alpine-elixir:1.8.1 as builder
COPY . /app
WORKDIR /app
RUN apk update && \
    apk --no-cache --update upgrade alpine-sdk && \
    apk --no-cache add alpine-sdk && \
    rm -rf /var/cache/**/*
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix format --check-formatted && \
    mix credo && \
    mix test
RUN MIX_ENV=prod mix release

FROM bitwalker/alpine-elixir:1.8.1
ENV REPLACE_OS_VARS=true
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/flair/ .
CMD ["bin/flair", "foreground"]
