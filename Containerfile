ARG IMAGE_NAME="${IMAGE_NAME:-lair}"
ARG SOURCE_IMAGE="${SOURCE_IMAGE:-fedora-toolbox-systemd-main}"
ARG SOURCE_ORG="${SOURCE_ORG}"
ARG SOURCE_REGISTRY="${SOURCE_REGISTRY:-ghcr.io/$SOURCE_ORG}"
ARG BASE_IMAGE="${SOURCE_REGISTRY}/${SOURCE_IMAGE}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-42}"
ARG IMAGE_REGISTRY=ghcr.io/nyahstack
ARG SOURCE_IMAGE_DIGEST=""

FROM scratch AS ctx
COPY build_files /

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION}${SOURCE_IMAGE_DIGEST:+@${SOURCE_IMAGE_DIGEST}}

ARG IMAGE_NAME="${IMAGE_NAME:-lair}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-42}"

COPY system_files /

# Run the setup scripts
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/run/context \
    --mount=type=tmpfs,dst=/tmp \
    /run/context/scripts/devbox.sh

VOLUME /var/lib/tool-overlay
