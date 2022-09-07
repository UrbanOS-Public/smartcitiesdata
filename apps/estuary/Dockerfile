FROM smartcitiesdata:build as builder
RUN cd apps/estuary/assets/ && \
    rm -rf node_modules && \
    npm install && \
    npm run deploy && \
    cd - && \
    mix cmd --app estuary mix do compile, phx.digest
RUN MIX_ENV=prod mix distillery.release --name estuary

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
COPY --from=builder /app/_build/prod/rel/estuary/ .
RUN chgrp -R 0 ${HOME} && \
    chmod -R g+rwX ${HOME}
USER default
ENV PORT=4000
EXPOSE ${PORT}
CMD ["bin/estuary", "foreground"]
