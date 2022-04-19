FROM smartcitiesdata:build as builder
RUN MIX_ENV=prod mix distillery.release --name discovery_api

FROM bitwalker/alpine-elixir:1.13.3
ENV REPLACE_OS_VARS=true
ENV CA_CERTFILE_PATH /etc/ssl/certs/ca-certificates.crt
RUN apk update && \
    apk add --no-cache bash openssl && \
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
