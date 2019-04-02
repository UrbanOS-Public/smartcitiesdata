FROM bitwalker/alpine-elixir:1.8.1
COPY . /app
WORKDIR /app
RUN apk update && \
    apk --no-cache --update upgrade alpine-sdk && \
    apk --no-cache add alpine-sdk && \
    rm -rf /var/cache/**/*
RUN mix local.hex --force \
    && mix local.rebar --force \
    && mix deps.get \
    && mix test \
    && mix format --check-formatted \
    && mix credo
