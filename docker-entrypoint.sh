#!/bin/sh
set -e

exec /opt/frigate/bin/frigate -n "${NETWORK:-mainnet}"