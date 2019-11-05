FROM bitwalker/alpine-elixir:1.9 as builder
COPY . /app
WORKDIR /app
RUN apk upgrade && \
    apk --no-cache --update upgrade alpine-sdk && \
    apk --no-cache add alpine-sdk && \
    rm -rf /var/cache/**/*
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get
RUN MIX_ENV=prod mix distillery.release

FROM bitwalker/alpine-elixir:1.9
ENV REPLACE_OS_VARS=true
RUN apk upgrade \
    && rm -rf /var/cache/**/*
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/valkyrie/ .
CMD ["bin/valkyrie", "foreground"]
