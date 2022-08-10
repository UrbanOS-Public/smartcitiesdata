FROM smartcitiesdata:build as builder
RUN MIX_ENV=prod mix distillery.release --name raptor

FROM hexpm/elixir:1.10.4-erlang-23.2.7.5-alpine-3.16.0
ENV REPLACE_OS_VARS=true
RUN apk update && \
    apk add --no-cache bash openssl && \
    rm -rf /var/cache/**/*
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/raptor/ .
ENV PORT 80
EXPOSE ${PORT}

CMD ["bin/raptor", "foreground"]
