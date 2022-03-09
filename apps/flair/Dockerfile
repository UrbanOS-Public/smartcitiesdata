FROM smartcitiesdata:build as builder
RUN MIX_ENV=prod mix distillery.release --name flair

FROM alpine:3.9
ENV REPLACE_OS_VARS=true
RUN apk update && \
    apk add --no-cache bash openssl && \
    rm -rf /var/cache/**/*
RUN chgrp -R 0 ${HOME} && \
    chmod -R g+rwX ${HOME}
COPY --from=builder /app/_build/prod/rel/flair/ .
USER default
CMD ["bin/flair", "foreground"]
