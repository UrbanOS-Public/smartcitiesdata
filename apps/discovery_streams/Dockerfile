FROM elixir:1.6.5
ENV MIX_ENV prod
ENV COTA_DATA_TOPIC "cota-vehicle-positions"
COPY . /app
WORKDIR /app
EXPOSE 4000
RUN mix local.hex --force \
    && mix local.rebar --force \
    && mix deps.get
CMD ["mix", "phx.server"]