FROM smartcitiesdata:build as builder
RUN MIX_ENV=prod mix distillery.release --name valkyrie

FROM bitwalker/alpine-elixir:1.10.4
ENV REPLACE_OS_VARS=true
RUN apk upgrade \
  && apk add --no-cache bash openssl \
  && rm -rf /var/cache/**/*
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/valkyrie/ .
ENV PORT=4000
EXPOSE ${PORT}
CMD ["bin/valkyrie", "foreground"]
