FROM debian:trixie-slim AS frigate

ARG TARGETPLATFORM
ARG FRIGATE_VERSION=1.5.2
ARG FRIGATE_PGP_SIG=E94618334C674B40

RUN \
  apt update && \
  apt install -y --no-install-recommends ca-certificates gnupg wget && \
  apt-get autoclean && \
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*

# Install frigate
RUN \
  if [ "${TARGETPLATFORM}" = "linux/arm64" ] ; then \
    ARCH="arm64" ; \
  else \
    ARCH="amd64" ; \
  fi && \
  echo "**** install Frigate ****" && \
  # Download and install Frigate
  wget https://github.com/sparrowwallet/frigate/releases/download/${FRIGATE_VERSION}/frigate_${FRIGATE_VERSION}_${ARCH}.deb \
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

FROM debian:trixie-slim

# Default / NVIDIA / Intel variant - built for amd64 and arm64.
#
# GPU support:
# - Intel OpenCL runtime installed from upstream compute-runtime releases
#   (intel-opencl-icd is not in Debian trixie repos); x86_64 only.
# - NVIDIA: no packages needed - Frigate bundles its own CUDA extension and
#   the NVIDIA container runtime injects driver libraries at launch time.
# - AMD: use the separate Dockerfile.amd image with Mesa Rusticl/radeonsi.
ARG TARGETPLATFORM
ARG INTEL_COMPUTE_RUNTIME_VERSION=26.18.38308.1
ARG INTEL_IGC_VERSION=2.34.4+21428
ARG INTEL_IGC_VERSION_SHORT=2.34.4

# Intel OpenCL runtime is installed on x86_64 only.
# A single compute-runtime package covers both i915 (Gen12 and older) and
# xe (Arc/Xe, Meteor Lake+, kernel >= 6.8) - no separate image needed per driver.
RUN if [ "${TARGETPLATFORM}" = "linux/amd64" ] ; then \
  apt update && \
  apt install -y --no-install-recommends \
    ca-certificates \
    ocl-icd-libopencl1 \
    wget && \
  wget -q \
    "https://github.com/intel/intel-graphics-compiler/releases/download/v${INTEL_IGC_VERSION_SHORT}/intel-igc-core-2_${INTEL_IGC_VERSION}_amd64.deb" \
    "https://github.com/intel/intel-graphics-compiler/releases/download/v${INTEL_IGC_VERSION_SHORT}/intel-igc-opencl-2_${INTEL_IGC_VERSION}_amd64.deb" \
    "https://github.com/intel/compute-runtime/releases/download/${INTEL_COMPUTE_RUNTIME_VERSION}/libigdgmm12_22.10.0_amd64.deb" \
    "https://github.com/intel/compute-runtime/releases/download/${INTEL_COMPUTE_RUNTIME_VERSION}/intel-opencl-icd_${INTEL_COMPUTE_RUNTIME_VERSION}-0_amd64.deb" && \
  dpkg -i \
    intel-igc-core-2_${INTEL_IGC_VERSION}_amd64.deb \
    intel-igc-opencl-2_${INTEL_IGC_VERSION}_amd64.deb \
    libigdgmm12_22.10.0_amd64.deb \
    intel-opencl-icd_${INTEL_COMPUTE_RUNTIME_VERSION}-0_amd64.deb && \
  rm -f \
    intel-igc-core-2_${INTEL_IGC_VERSION}_amd64.deb \
    intel-igc-opencl-2_${INTEL_IGC_VERSION}_amd64.deb \
    libigdgmm12_22.10.0_amd64.deb \
    intel-opencl-icd_${INTEL_COMPUTE_RUNTIME_VERSION}-0_amd64.deb && \
  apt-get remove -y wget && \
  apt-get autoclean && \
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/* ; \
fi

COPY --from=frigate /opt/frigate /opt/frigate
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENV NETWORK=mainnet

EXPOSE 57001
VOLUME /root/.frigate

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
