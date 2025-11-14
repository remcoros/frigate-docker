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

A configuration file `config` should be placed in the mounted volume directory. See the [frigate documentation](https://github.com/sparrowwallet/frigate) for details on configuration options.

This uses 'mainnet' by default. If you want to run on e.g. testnet 4, you can set the `NETWORK` environment variable:

```bash
docker run -d --name frigate \
    -p 57001:57001 \
    -v /home/user/.frigate:/root/.frigate \
    -e NETWORK=testnet4 \
    ghcr.io/remcoros/frigate-docker:latest
```

## Licence

This project and Frigate are licensed under the [GPL License](LICENSE).