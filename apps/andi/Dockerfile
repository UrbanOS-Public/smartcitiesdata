FROM smartcitiesdata:build as builder
RUN cd apps/andi/assets/ && \
    rm -rf node_modules && \
    npm install && \
    npm run deploy && \
    cd - && \
    mix cmd --app andi mix do compile, phx.digest
RUN MIX_ENV=prod mix distillery.release --name andi

FROM alpine:3.9
ENV REPLACE_OS_VARS=true
ENV CA_CERTFILE_PATH /etc/ssl/certs/ca-certificates.crt
RUN apk update && \
  apk add --no-cache bash openssl && \
  rm -rf /var/cache/**/*
RUN chgrp -R 0 ${HOME} && \
    chmod -R g+rwX ${HOME}
COPY --from=builder ${CA_CERTFILE_PATH} ${CA_CERTFILE_PATH}
COPY --from=builder /app/_build/prod/rel/andi/ .
USER default
ENV PORT 80
EXPOSE ${PORT}
COPY start.sh /
CMD ["/start.sh"]
