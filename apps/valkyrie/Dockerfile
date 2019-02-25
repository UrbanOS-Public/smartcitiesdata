FROM bitwalker/alpine-elixir:1.7.2 as builder
ENV MIX_ENV test
COPY . /app
WORKDIR /app
RUN apk update && \
    apk add make && \
    apk add g++
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix format --check-formatted && \
    mix test
RUN MIX_ENV=prod mix release

FROM bitwalker/alpine-elixir:1.7.2
ENV REPLACE_OS_VARS=true
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/valkyrie/ .
CMD ["bin/valkyrie", "foreground"]
