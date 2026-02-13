# devbox image

Fedora-based distrobox/toolbox image with JetBrains Toolbox helpers, user overlay setup, and curated developer tooling.

## Features
- Digest-pinned upstream base verified with cosign before build
- JetBrains Toolbox install/sync services, plus profile hook for Toolbox scripts
- Rootless podman + systemd behavior inherited from the pinned `fedora-toolbox-systemd-*` base image
- mise for language/runtime management and preinstalled CLI essentials from `devbox.packages`

## Usage
1. Build or pull: `podman pull ghcr.io/<OWNER>/devbox:latest` (replace `<OWNER>`).
2. Create via distrobox: `distrobox-create -i ghcr.io/<OWNER>/devbox:latest -n devbox`.
3. Enter: `distrobox-enter devbox`.

## Development
- Containerfile: `Containerfile`
- Packages: `build_files/devbox.packages`
- System files/services: `system_files/`
- Build workflows: `.github/workflows/build-latest.yml`, `.github/workflows/build-gts.yml`, `.github/workflows/reusable-build.yml`

## Local Build Tasks
- List recipes: `just --list`
- Show pinned bases: `just list-base-images`
- Generate tags: `just gen-tags devbox 43 main` or `just gen-tags devbox 42 nvidia`
- Build image: `just build devbox 43 main` or `just build devbox 42 nvidia`
- Push image: `just push devbox 43 main` or `just push devbox 42 nvidia`
- Sign pushed tags: `just sign devbox 43 main` or `just sign devbox 42 nvidia`
