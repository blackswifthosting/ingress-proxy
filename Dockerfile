
FROM chainguard/wolfi-base

RUN apk --no-cache add caddy ca-certificates curl
COPY Caddyfile /etc/caddy/Caddyfile
ENV TARGET_HOST="www.example.tld" \
    TARGET_HTTP_PORT="80" \
    TARGET_HTTPS_PORT="443"

CMD ["caddy","run","-c","/etc/caddy/Caddyfile"]
