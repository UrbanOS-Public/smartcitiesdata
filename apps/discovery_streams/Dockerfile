FROM elixir:1.7.2
ENV MIX_ENV test
COPY . /app
WORKDIR /app
RUN mix local.hex --force  && \
    mix local.rebar --force && \
    mix deps.get && \
    mix test

FROM elixir:1.7.2
ENV MIX_ENV prod
ENV COTA_DATA_TOPIC "cota-vehicle-positions"
COPY . /app
WORKDIR /app
EXPOSE 4000
RUN mix local.hex --force \
    && mix local.rebar --force \
    && mix deps.get
CMD ["./run.sh"]
