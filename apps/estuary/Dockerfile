FROM smartcitiesdata:build as builder
RUN MIX_ENV=prod mix distillery.release --name estuary

FROM bitwalker/alpine-elixir:1.8.1
ENV REPLACE_OS_VARS=true
RUN apk upgrade \
  && apk add --no-cache bash openssl \
  && rm -rf /var/cache/**/*
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/estuary/ .
ENV PORT=4000
EXPOSE ${PORT}
CMD ["bin/estuary", "foreground"]