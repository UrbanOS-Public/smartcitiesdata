FROM bitwalker/alpine-elixir:1.8.1 as builder

RUN MIX_ENV=prod mix distillery.release --name discovery_api

FROM alpine:3.9
ENV REPLACE_OS_VARS=true
RUN apk update && \
    apk add --no-cache bash openssl && \
    rm -rf /var/cache/**/*
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/discovery_api/ .
ENV PORT 80
EXPOSE ${PORT}
CMD ["bin/discovery_api", "foreground"]
