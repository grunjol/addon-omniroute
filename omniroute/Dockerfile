FROM diegosouzapw/omniroute:3.8.48

USER root

RUN apt-get update && apt-get install -y --no-install-recommends nginx-light \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default

COPY rootfs /

RUN chmod +x /run.sh

EXPOSE 20128

CMD ["/run.sh"]

LABEL \
  org.opencontainers.image.title="Home Assistant App: OmniRoute" \
  org.opencontainers.image.description="Unified AI proxy. Route any LLM through one endpoint." \
  org.opencontainers.image.source="https://github.com/grunjol/addon-omniroute" \
  org.opencontainers.image.licenses="MIT"
