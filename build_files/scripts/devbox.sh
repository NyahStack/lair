#!/usr/bin/env bash
set -euo pipefail

for script in /run/context/scripts/[0-9][0-9]-*.sh; do
  [ -f "$script" ] || continue
  echo "Running ${script##*/}..."
  "$script"
done
