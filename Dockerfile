FROM debian:trixie-slim AS frigate

ARG TARGETPLATFORM
ARG FRIGATE_VERSION=1.6.1
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
  case "${TARGETPLATFORM}" in \
    "linux/amd64") ARCH="amd64" ;; \
    "linux/arm64") ARCH="arm64" ;; \
    *) echo "Unsupported target platform: ${TARGETPLATFORM}" >&2; exit 1 ;; \
  esac && \
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
ARG INTEL_COMPUTE_RUNTIME_VERSION=26.35.39758.10
ARG INTEL_IGC_VERSION=2.41.5+22716
ARG INTEL_IGC_VERSION_SHORT=2.41.5
ARG INTEL_IGC_CORE_SHA256=0a6e64a663ae65a0fa02d6912ae3b6b37cf85b90c21cc423fd9fef70aaf4f628
ARG INTEL_IGC_OPENCL_SHA256=779e1b9e88098eb25711e9a8f67c2752665bad22f134aa40ed5649f6e1b87058
ARG INTEL_GMMLIB_SHA256=6031a63d6e8a12ce61c14efc15f2c8e727061286e3820b8594e6d00615e04d54
ARG INTEL_OPENCL_SHA256=61712caaddeba3d38e4f79e2a0fb23fea25596ca2d72c3144c6eea2331ec4301

# Intel OpenCL runtime is installed on x86_64 only.
# The pinned compute-runtime release supports platforms using both the i915 and
# xe kernel drivers, so no separate image is needed per driver.
RUN if [ "${TARGETPLATFORM}" = "linux/amd64" ] ; then \
  apt update && \
  apt install -y --no-install-recommends \
    ca-certificates \
    clinfo \
    ocl-icd-libopencl1 \
    wget && \
  wget -q \
    "https://github.com/intel/intel-graphics-compiler/releases/download/v${INTEL_IGC_VERSION_SHORT}/intel-igc-core-2_${INTEL_IGC_VERSION}_amd64.deb" \
    "https://github.com/intel/intel-graphics-compiler/releases/download/v${INTEL_IGC_VERSION_SHORT}/intel-igc-opencl-2_${INTEL_IGC_VERSION}_amd64.deb" \
    "https://github.com/intel/compute-runtime/releases/download/${INTEL_COMPUTE_RUNTIME_VERSION}/libigdgmm12_22.10.0_amd64.deb" \
    "https://github.com/intel/compute-runtime/releases/download/${INTEL_COMPUTE_RUNTIME_VERSION}/intel-opencl-icd_${INTEL_COMPUTE_RUNTIME_VERSION}-0_amd64.deb" && \
  printf '%s  %s\n' \
    "${INTEL_IGC_CORE_SHA256}" "intel-igc-core-2_${INTEL_IGC_VERSION}_amd64.deb" \
    "${INTEL_IGC_OPENCL_SHA256}" "intel-igc-opencl-2_${INTEL_IGC_VERSION}_amd64.deb" \
    "${INTEL_GMMLIB_SHA256}" "libigdgmm12_22.10.0_amd64.deb" \
    "${INTEL_OPENCL_SHA256}" "intel-opencl-icd_${INTEL_COMPUTE_RUNTIME_VERSION}-0_amd64.deb" \
    | sha256sum --check --strict - && \
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

EXPOSE 50001 50002
VOLUME /root/.frigate

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
