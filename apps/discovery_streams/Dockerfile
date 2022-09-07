FROM smartcitiesdata:build as builder
RUN MIX_ENV=prod mix distillery.release --name discovery_streams

FROM hexpm/elixir:1.10.4-erlang-23.2.7.5-alpine-3.16.0
ENV HOME /opt/app
ENV REPLACE_OS_VARS=true
WORKDIR ${HOME}
RUN adduser -s /bin/sh -u 1001 -G root -h "${HOME}" -S -D default && \
    chown -R 1001:0 "${HOME}" && \
    apk upgrade && \
    apk update && \
    apk add --no-cache bash openssl && \
    rm -rf /var/cache/**/*
COPY --from=builder /app/_build/prod/rel/discovery_streams/ .
RUN chgrp -R 0 ${HOME} && \
    chmod -R g+rwX ${HOME}
USER default
ENV PORT 4000
EXPOSE ${PORT}
CMD ["bin/discovery_streams", "foreground"]
