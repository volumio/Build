# Container that runs the checker
FROM alpine:latest
LABEL "name"="ShellChecekr"
LABEL "maintainer"="ashthespy <https://github.com/ashthespy/>"

# Pull in required binaries for shellcheck and shfmt
ARG scversion="stable" 
ARG shversion="3.2.1" 

# Install directly from github releases
RUN apk add --no-cache bash git grep jq \
    && apk add --no-cache --virtual .dload-deps tar \
    && wget -qO- "https://github.com/koalaman/shellcheck/releases/download/${scversion?}/shellcheck-${scversion?}.linux.x86_64.tar.xz" | tar -xJ -C /usr/local/bin/ --strip-components=1 --wildcards '*/shellcheck' \
    && wget -q "https://github.com/mvdan/sh/releases/download/v${shversion}/shfmt_v${shversion}_linux_amd64" -O /usr/local/bin/shfmt \
    && apk del --no-cache .dload-deps \
    && chmod +x /usr/local/bin/shellcheck \
    && chmod +x /usr/local/bin/shfmt  \
    && rm -rf /tmp/*

# Default entry point that runs our tests
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
