# The image the suites run in: what the tools need on a workstation, and what the transfer pods need
# (the kube binaries are copied in by tests/run, from tests/fetch-binaries)
FROM debian:stable-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends attr awscli ca-certificates jq openssl procps python3 tar gzip \
 && rm -rf /var/lib/apt/lists/*
