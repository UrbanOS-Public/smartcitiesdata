FROM smartcitiesdata:build as builder
RUN MIX_ENV=prod mix distillery.release --name alchemist

FROM hexpm/elixir:1.14.4-erlang-25.3.2-alpine-3.18.0
ENV HOME /opt/app
ENV REPLACE_OS_VARS=true
WORKDIR ${HOME}
RUN adduser -s /bin/sh -u 1001 -G root -h "${HOME}" -S -D default && \
  chown -R 1001:0 "${HOME}" && \
  apk upgrade && \
  apk update \
  && apk add --no-cache bash openssl \
  && rm -rf /var/cache/**/*
COPY --from=builder /app/_build/prod/rel/alchemist/ .
RUN chgrp -R 0 ${HOME} && \
    chmod -R g+rwX ${HOME}
USER default
ENV PORT=4000
EXPOSE ${PORT}
CMD ["bin/alchemist", "foreground"]
