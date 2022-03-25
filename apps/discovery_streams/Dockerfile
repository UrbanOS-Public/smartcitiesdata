FROM smartcitiesdata:build as builder
RUN MIX_ENV=prod mix distillery.release --name discovery_streams

FROM bitwalker/alpine-elixir:1.10.4
ENV REPLACE_OS_VARS=true
RUN apk upgrade && \
    apk add --no-cache bash openssl && \
    rm -rf /var/cache/**/*
COPY --from=builder /app/_build/prod/rel/discovery_streams/ .
RUN chgrp -R 0 ${HOME} && \
    chmod -R g+rwX ${HOME}
USER default
ENV PORT 4000
EXPOSE ${PORT}
CMD ["bin/discovery_streams", "foreground"]
