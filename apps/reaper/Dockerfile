FROM smartcitiesdata:build as builder
RUN MIX_ENV=prod mix release reaper

#FROM hexpm/elixir:1.10.4-erlang-23.2.7.5-alpine-3.16.9
FROM hexpm/elixir:1.14.4-erlang-25.3.2-alpine-3.18.0

ENV HOME /opt/app
ENV REPLACE_OS_VARS=true
WORKDIR ${HOME}
ENV CA_CERTFILE_PATH /etc/ssl/certs/ca-certificates.crt
RUN adduser -s /bin/sh -u 1001 -G root -h "${HOME}" -S -D default && \
    chown -R 1001:0 "${HOME}" && \
    apk upgrade && \
    apk update && \
    apk add --no-cache bash openssl && \
    rm -rf /var/cache/**/*
COPY --from=builder ${CA_CERTFILE_PATH} ${CA_CERTFILE_PATH}
COPY --from=builder /app/_build/prod/rel/reaper/ .
RUN chgrp -R 0 ${HOME} && \
    chmod -R g+rwX ${HOME}
USER default
ENV PORT=4000
EXPOSE ${PORT}
CMD ["bin/reaper", "start"]
