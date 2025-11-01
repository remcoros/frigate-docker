# taken from https://github.com/linuxserver/docker-baseimage-kasmvnc/blob/debianbookworm/Dockerfile
# modified to apply 'novnc.patch' (fixing a disconnect/reconnect issue)
FROM debian:bookworm-slim

ARG TARGETPLATFORM
ARG FRIGATE_VERSION=1.2.0
ARG FRIGATE_PGP_SIG=E94618334C674B40

RUN \
  apt update && \
  apt install -y --no-install-recommends ca-certificates gnupg wget

# Install frigate
RUN \
  if [ "${TARGETPLATFORM}" = "linux/arm64" ] ; then \
    ARCH="arm64" ; \
  else \
    ARCH="amd64" ; \
  fi && \
  echo "**** install Frigate ****" && \
  # Download and install Frigate
  wget  https://github.com/sparrowwallet/frigate/releases/download/${FRIGATE_VERSION}/frigate_${FRIGATE_VERSION}_${ARCH}.deb \
               https://github.com/sparrowwallet/frigate/releases/download/${FRIGATE_VERSION}/frigate-${FRIGATE_VERSION}-manifest.txt \
               https://github.com/sparrowwallet/frigate/releases/download/${FRIGATE_VERSION}/frigate-${FRIGATE_VERSION}-manifest.txt.asc \
               https://keybase.io/craigraw/pgp_keys.asc && \
  # verify pgp and sha signatures
  gpg --import pgp_keys.asc && \
  gpg --status-fd 1 --verify frigate-${FRIGATE_VERSION}-manifest.txt.asc | grep -q "GOODSIG ${FRIGATE_PGP_SIG} Craig Raw <craig@sparrowwallet.com>" || exit 1 && \
  sha256sum --check frigate-${FRIGATE_VERSION}-manifest.txt --ignore-missing || exit 1 && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install -y ./frigate_${FRIGATE_VERSION}_${ARCH}.deb && \
  # cleanup
  rm ./frigate* ./pgp_keys.asc

EXPOSE 57001
VOLUME /root/.frigate

ENTRYPOINT ["/opt/frigate/bin/frigate", "-n", "mainnet"]
