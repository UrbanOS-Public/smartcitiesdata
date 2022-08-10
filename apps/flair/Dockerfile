FROM smartcitiesdata:build as builder
RUN MIX_ENV=prod mix distillery.release --name flair

FROM alpine:3.16
ENV REPLACE_OS_VARS=true
RUN apk update && \
    apk add --no-cache bash openssl && \
    rm -rf /var/cache/**/*
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/flair/ .
CMD ["bin/flair", "foreground"]
