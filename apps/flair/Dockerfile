FROM smartcitiesdata:build as builder
RUN MIX_ENV=prod mix distillery.release --name forklift

FROM alpine:3.9
ENV REPLACE_OS_VARS=true
RUN apk update && \
    apk --no-cache bash openssl && \
    rm -rf /var/cache/**/*
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/flair/ .
CMD ["bin/flair", "foreground"]
