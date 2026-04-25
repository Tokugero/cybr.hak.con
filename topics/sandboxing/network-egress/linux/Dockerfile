# Workshop image for the network-egress topic.
#
# ubuntu:24.04 plus the small set of tools the egress-probe needs:
# curl (HTTP), dnsutils (dig), netcat-openbsd (raw TCP), ca-certificates
# (so HTTPS verifies cleanly).
#
# Built once via `docker build -t cybr-hak-con-egress .` (or implicitly
# by the run scripts and tests/run.sh). Reused across the workshop's
# baseline and sidecar runs.

FROM ubuntu:24.04

RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        dnsutils \
        netcat-openbsd \
        iproute2 && \
    rm -rf /var/lib/apt/lists/*

# Default to bash so the probe scripts work
SHELL ["/bin/bash", "-c"]
