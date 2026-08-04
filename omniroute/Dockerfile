FROM diegosouzapw/omniroute:3.8.49

USER root

RUN apt-get update && apt-get install -y --no-install-recommends patch && \
    rm -rf /var/lib/apt/lists/*

COPY pr-9353.patch /tmp/pr-9353.patch
RUN patch -p1 -d /app < /tmp/pr-9353.patch && rm /tmp/pr-9353.patch

LABEL \
  org.opencontainers.image.title="Home Assistant App: OmniRoute" \
  org.opencontainers.image.description="Unified AI proxy. Route any LLM through one endpoint." \
  org.opencontainers.image.source="https://github.com/grunjol/addon-omniroute" \
  org.opencontainers.image.licenses="MIT"
