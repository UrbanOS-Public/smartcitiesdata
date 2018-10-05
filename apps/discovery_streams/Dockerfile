FROM elixir:1.7.2 as builder
ENV MIX_ENV test
COPY . /app
WORKDIR /app
RUN mix local.hex --force  && \
    mix local.rebar --force && \
    mix deps.get && \
    mix test
RUN MIX_ENV=prod mix release

FROM elixir:1.7.2
ENV COTA_DATA_TOPIC "cota-vehicle-positions"
ENV REPLACE_OS_VARS=true
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/cota_streaming_consumer/ .
ENV PORT 4000
EXPOSE 4000
CMD ["bin/cota_streaming_consumer", "foreground"]
