# Docker container for frigate

    NOTE: this is a work in progress and details may change.

This repository contains a Dockerfile to build an image for [Frigate Electrum Server](https://github.com/sparrowwallet/frigate).

## Building the image

Simple local build (current architecture):

```bash
docker build -t frigate:local .
```

## Running the container

The Dockerfile exposes port `57001` (Frigate electrum port). Map it to a host port of your choice (use same port unless you have a conflict).

Persistent data is stored in the container at `/root/.frigate` (declared as a volume). To persist across container recreations, mount a host directory.

```bash
docker run -d --name frigate \
    -p 57001:57001 \
    -v /home/user/.frigate:/root/.frigate \
    ghcr.io/remcoros/frigate-docker:latest
```

A configuration file `config.toml` should be placed in the mounted volume directory. See the [frigate documentation](https://github.com/sparrowwallet/frigate) for details on configuration options.

This uses 'mainnet' by default. If you want to run on e.g. testnet 4, you can set the `NETWORK` environment variable:

```bash
docker run -d --name frigate \
    -p 57001:57001 \
    -v /home/user/.frigate:/root/.frigate \
    -e NETWORK=testnet4 \
    ghcr.io/remcoros/frigate-docker:latest
```

## GPU Acceleration

Frigate 1.5.0+ supports GPU-accelerated Silent Payments scanning via CUDA (NVIDIA), OpenCL (Intel/AMD), and Metal (Apple). The image includes the Intel OpenCL runtime (installed from [intel/compute-runtime](https://github.com/intel/compute-runtime)) and the OpenCL ICD loader (`ocl-icd-libopencl1`). CUDA support requires no additional packages — Frigate bundles its own extension. AMD requires the ROCm runtime on the host.

Set `computeBackend = "AUTO"` (default) in `config.toml` to auto-detect the best available backend, or `"GPU"` / `"CPU"` to force one.

See `docker-compose.gpu.yml` for ready-to-use examples for each GPU vendor.

### NVIDIA

Requires NVIDIA driver 570.86.15+ and [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) on the host.

```bash
docker run -d --name frigate \
    --gpus all \
    -p 57001:57001 \
    -v /home/user/.frigate:/root/.frigate \
    ghcr.io/remcoros/frigate-docker:latest
```

### Intel iGPU (OpenCL)

The Intel OpenCL runtime is bundled in the image. Pass through `/dev/dri` and ensure the user running the container is in the `render` group (`sudo usermod -aG render $USER`).

```bash
docker run -d --name frigate \
    --device /dev/dri \
    -p 57001:57001 \
    -v /home/user/.frigate:/root/.frigate \
    ghcr.io/remcoros/frigate-docker:latest
```

### AMD (OpenCL via ROCm)

Requires the [ROCm OpenCL runtime](https://rocm.docs.amd.com/en/latest/deploy/linux/index.html) installed on the host. Mount the host's OpenCL vendor config and pass through the DRI and KFD devices. The user must be in the `render` and `video` groups.

```bash
docker run -d --name frigate \
    --device /dev/dri \
    --device /dev/kfd \
    -v /etc/OpenCL/vendors:/etc/OpenCL/vendors:ro \
    -p 57001:57001 \
    -v /home/user/.frigate:/root/.frigate \
    ghcr.io/remcoros/frigate-docker:latest
```

## Licence

This project and Frigate are licensed under the [GPL License](LICENSE).