#!/usr/bin/env bash

# src: https://github.com/ublue-os/bazzite-dx/blob/1b91935ba127474e835229a91b7b483ffd41b98b/build_files/scripts/log.sh

group() {
  WHAT=$1
  shift
  echo "::group:: === $WHAT ==="
}

log() {
  echo "=== $* ==="
}
