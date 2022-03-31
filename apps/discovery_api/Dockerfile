FROM smartcitiesdata:build as builder
RUN MIX_ENV=prod mix distillery.release --name discovery_api

FROM alpine:3.9
ENV REPLACE_OS_VARS=true
ENV CA_CERTFILE_PATH /etc/ssl/certs/ca-certificates.crt
RUN apk update && \
    apk add --no-cache bash openssl && \
    rm -rf /var/cache/**/*
COPY --from=builder ${CA_CERTFILE_PATH} ${CA_CERTFILE_PATH}
COPY --from=builder /app/_build/prod/rel/discovery_api/ .
RUN chgrp -R 0 ${HOME} && \
    chmod -R g+rwX ${HOME}
ENV PORT 80
EXPOSE ${PORT}

COPY set-up.sh /
COPY start.sh /
USER default
CMD ["/start.sh"]
