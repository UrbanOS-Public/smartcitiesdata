FROM smartcitiesdata:build as builder
RUN cd apps/estuary/assets/ && \
    rm -rf node_modules && \
    npm install && \
    npm run deploy && \
    cd - && \
    mix cmd --app estuary mix do compile, phx.digest
RUN MIX_ENV=prod mix distillery.release --name estuary

FROM bitwalker/alpine-elixir:1.10.4
ENV REPLACE_OS_VARS=true
RUN apk upgrade \
  && apk add --no-cache bash openssl \
  && rm -rf /var/cache/**/*
COPY --from=builder /app/_build/prod/rel/estuary/ .
RUN chgrp -R 0 ${HOME} && \
    chmod -R g+rwX ${HOME}
USER default
ENV PORT=4000
EXPOSE ${PORT}
CMD ["bin/estuary", "foreground"]