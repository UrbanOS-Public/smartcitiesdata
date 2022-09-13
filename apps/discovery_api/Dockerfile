FROM smartcitiesdata:build as builder
RUN MIX_ENV=prod mix distillery.release --name discovery_api

FROM hexpm/elixir:1.10.4-erlang-23.2.7.5-alpine-3.16.0
ENV HOME /opt/app
ENV REPLACE_OS_VARS=true
ENV CA_CERTFILE_PATH /etc/ssl/certs/ca-certificates.crt
WORKDIR ${HOME}
RUN adduser -s /bin/sh -u 1001 -G root -h "${HOME}" -S -D default && \
    chown -R 1001:0 "${HOME}" && \
    apk upgrade && \
    apk update && \
    apk add --no-cache bash zlib busybox ssl_client libssl1.1 openssl libcrypto1.1 && \
    rm -rf /var/cache/**/*
COPY --from=builder ${CA_CERTFILE_PATH} ${CA_CERTFILE_PATH}
COPY --from=builder /app/_build/prod/rel/discovery_api/ .
RUN chgrp -R 0 ${HOME} && \
    chmod -R g+rwX ${HOME}
USER default

ENV PORT 4000
EXPOSE ${PORT}
COPY set-up.sh ${HOME}
COPY start.sh ${HOME}
CMD ["./start.sh"]
