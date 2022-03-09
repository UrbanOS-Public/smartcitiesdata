FROM smartcitiesdata:build as builder
RUN MIX_ENV=prod mix distillery.release --name forklift

FROM bitwalker/alpine-elixir:1.13.3
ENV REPLACE_OS_VARS=true
RUN apk upgrade \
  && apk add --no-cache bash openssl \
  && rm -rf /var/cache/**/*
RUN chgrp -R 0 ${HOME} && \
    chmod -R g+rwX ${HOME}
COPY --from=builder /app/_build/prod/rel/forklift/ .
USER default
ENV PORT=4000
EXPOSE ${PORT}
CMD ["bin/forklift", "foreground"]
