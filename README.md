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
docker run -d --name frigate -p 57001:57001 -v /home/user/.frigate:/root/.frigate frigate:latest
```

A configuration file `config` should be placed in the mounted volume directory. See the [frigate documentation](https://github.com/sparrowwallet/frigate) for details on configuration options.

## Licence

This project and Frigate are licensed under the [GPL License](LICENSE).