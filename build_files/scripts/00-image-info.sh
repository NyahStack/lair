#!/usr/bin/env bash
set -euo pipefail

OS_RELEASE="/usr/lib/os-release"

get_field() {
  local key=$1
  awk -F= -v k="$key" '$1==k {sub(/^"/,"",$2); sub(/"$/,"",$2); print $2}' "$OS_RELEASE" | head -n1
}

set_field() {
  local key=$1 value=$2
  if grep -q "^${key}=" "$OS_RELEASE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$OS_RELEASE"
  else
    echo "${key}=${value}" >>"$OS_RELEASE"
  fi
}

version_id="$(get_field VERSION_ID)"
version_id="${version_id:-unknown}"

image_name="${IMAGE_NAME:-lair}"
variant_id="${IMAGE_VARIANT_ID:-$image_name}"
variant_name="${IMAGE_VARIANT_NAME:-Devbox}"
image_version="${IMAGE_VERSION:-$version_id}"
image_pretty="${IMAGE_PRETTY_NAME:-Fedora Linux ${image_version} (${variant_name})}"
image_id="${IMAGE_ID:-${image_name}-${image_version}}"
default_hostname="${DEFAULT_HOSTNAME:-$variant_id}"
image_summary="${IMAGE_SUMMARY:-Fedora-based devbox image}"

set_field VERSION "\"${image_version} (${variant_name})\""
set_field PRETTY_NAME "\"${image_pretty}\""
set_field VARIANT "\"${variant_name}\""
set_field VARIANT_ID "${variant_id}"
set_field IMAGE_ID "\"${image_id}\""
set_field DEFAULT_HOSTNAME "\"${default_hostname}\""
set_field IMAGE_SUMMARY "\"${image_summary}\""
