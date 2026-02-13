set unstable := true
set shell := ["bash", "-euo", "pipefail", "-c"]

# Tags
gts := "42"
latest := "43"
[private]
beta := "44"

# Defaults
default_version := latest
default_image := "lair"
default_variant := "main"

# Reused Values
org := "NyahStack"
repo := "lair"
IMAGE_REGISTRY := "ghcr.io" / lowercase(org)

[private]
source_org := lowercase(org)
source_registry := "ghcr.io" / source_org

# Image File
[private]
image-file := justfile_dir() / "image-versions.yaml"

# Image Names
[private]
images := '(
  ["lair"]="fedora-toolbox-systemd-main"
  ["lair-nvidia"]="fedora-toolbox-systemd-nvidia"
)'

# Fedora Versions
[private]
fedora_versions := '(
    ["gts"]="' + gts + '"
    ["' + gts + '"]="' + gts + '"
    ["latest"]="' + latest + '"
    ["' + latest + '"]="' + latest + '"
    ["beta"]="' + beta + '"
    ["' + beta + '"]="' + beta + '"
)'

# Variants
[private]
variants := '(
  ["main"]="main"
  ["nvidia"]="nvidia"
)'

# Helpers
[private]
SUDO_DISPLAY := env("DISPLAY", "") || env("WAYLAND_DISPLAY", "")
[private]
SUDOIF := if `id -u` == "0" { "" } else if SUDO_DISPLAY != "" { which("sudo") + " --askpass" } else { which("sudo") }
[private]
just := just_executable()
[private]
PODMAN := which("podman") || require("podman-remote")

# Make things quieter by default
[private]
export SET_X := if `id -u` == "0" { "1" } else { env('SET_X', '') }

# Aliases
alias build := build-container
alias push := push-to-registry
alias sign := cosign-sign

# Utility
[private]
default-inputs := '
: ${fedora_version:=' + default_version + '}
: ${image_name:=' + default_image + '}
: ${variant:=' + default_variant + '}
'
[private]
get-names := '
declare -a _images="$(' + just + ' image-name-check $image_name $fedora_version $variant)"
if [[ -z ${_images[0]:-} ]]; then
    exit 1
fi
image_name="${_images[0]}"
source_image_name="${_images[1]}"
fedora_version="${_images[2]}"
'
[private]
build-missing := '
cmd="' + just + ' build ${image_name%-*} $fedora_version $variant"
if ! ' + PODMAN + ' image exists "localhost/$image_name:$fedora_version"; then
    echo "' + style('warning') + 'Warning' + NORMAL +': Container Does Not Exist..." >&2
    echo "' + style('warning') + 'Will Run' + NORMAL +': ' + style('command') + '$cmd' + NORMAL +'" >&2
    seconds=5
    while [ $seconds -gt 0 ]; do
        printf "\rTime remaining: ' + style('error') + '%d' + NORMAL + ' seconds to cancel" $seconds >&2
        sleep 1
        (( seconds-- ))
    done
    echo "" >&2
    echo "'+ style('warning') +'Running'+ NORMAL+ ': '+ style('command') +'$cmd'+ NORMAL+ '" >&2
    $cmd
fi
'
[private]
pull-retry := '
function pull-retry() {
    local target="$1"
    local retries=3
    trap "exit 1" SIGINT
    while [ $retries -gt 0 ]; do
        ' + PODMAN + ' pull $target && break
        (( retries-- ))
    done
    if ! (( retries )); then
        echo "' + style('error') +' Unable to pull ${target/@*/}...' + NORMAL +'" >&2
        exit 1
    fi
    trap - SIGINT
}
'

default:
  @{{ just }} --list

# Check Valid Image Name
[group("Utility")]
image-name-check $image_name $fedora_version $variant:
  #!/usr/bin/env bash
  set ${SET_X:+-x} -eou pipefail
  declare -A images={{ images }}

  {{ default-inputs }}

  if [[ "$image_name" =~ -main$|-nvidia$ ]]; then
    image_name="${image_name%-*}"
  fi

  fedora_version="$({{ just }} fedora-version-check $fedora_version || exit 1)"
  variant="$({{ just }} fedora-variant-check $variant || exit 1)"

  if [[ ! "$variant" =~ ^main$ ]]; then
    image_name="$image_name-$variant"
  fi

  source_image_name="${images[$image_name]:-}"
  if [[ -z "$source_image_name" ]]; then
    echo '{{ style('error') }}Invalid Image Name{{ NORMAL }}' >&2
    exit 1
  fi

  echo "($image_name $source_image_name $fedora_version)"

# Check Valid Fedora Version
[group('Utility')]
fedora-version-check $fedora_version:
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    declare -A fedora_versions={{ fedora_versions }}
    if [[ -z "${fedora_versions[$fedora_version]:-}" ]]; then
        echo "{{ style('error') }}Not a supported version{{ NORMAL }}" >&2
        exit 1
    fi
    echo "${fedora_versions[$fedora_version]}"

# Check Valid Variant
[group('Utility')]
fedora-variant-check $variant:
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail
    declare -A variants={{ variants }}
    if [[ -z "${variants[$variant]:-}" ]]; then
        echo "{{ style('error') }}Not a supported variant{{ NORMAL }}" >&2
        exit 1
    fi
    echo "${variants[$variant]}"

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/env bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Checking syntax: $file" >&2
        {{ just }} --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile" >&2
    {{ just }} --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/env bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Checking syntax: $file" >&2
        {{ just }} --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile" >&2
    {{ just }} --unstable --fmt -f Justfile || { exit 1; }

[group("Utility")]
list-base-images:
  @awk '$1 == "-" && $2 == "name:" { name = $3; next } $1 == "image:" { image = $2; next } $1 == "tag:" { tag = $2; gsub(/"/, "", tag); next } $1 == "digest:" { digest = $2; if (name ~ /^fedora-toolbox-systemd-(main|nvidia)-(42|43)$/) printf "%s: %s:%s@%s\n", name, image, tag, digest }' {{ image-file }}

[group("Utility")]
gen-tags image_name="" fedora_version="" variant="" github="":
  #!/usr/bin/bash
  set ${SET_X:+-x} -eou pipefail

  {{ default-inputs }}
  {{ get-names }}

  # Generate Timestamp with incrementing version point
  TIMESTAMP="$(date +%Y%m%d)"
  LIST_TAGS="$(mktemp)"
  trap 'rm -f "$LIST_TAGS"' EXIT
  for i in {1..5}; do
    if skopeo list-tags "docker://{{ IMAGE_REGISTRY }}/$image_name" > "$LIST_TAGS"; then
      break
    fi
    sleep $((5 * i))
  done
  if [[ ! -s "$LIST_TAGS" ]]; then
    echo '{"Tags":[]}' > "$LIST_TAGS"
  fi

  if [[ "$fedora_version" == "{{ latest }}" ]]; then
    base_tag="latest"
  else
    base_tag="gts"
  fi
  if [[ "$variant" == "nvidia" ]]; then
    base_tag="$base_tag-nvidia"
  fi

  if jq -e --arg tag "$fedora_version-$TIMESTAMP" 'any((.Tags // [])[]; contains($tag))' "$LIST_TAGS" >/dev/null; then
    POINT=1
    while jq -e --arg tag "$base_tag-$TIMESTAMP.$POINT" 'any((.Tags // [])[]; contains($tag))' "$LIST_TAGS" >/dev/null; do
      (( POINT++ ))
    done
    TIMESTAMP="$TIMESTAMP.$POINT"
  fi

  # Add a sha tag for tracking builds during a pull request
  SHA_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo init)"

  # Define Versions
  if [[ "$fedora_version" -eq "{{ gts }}" ]]; then
    COMMIT_TAGS=("$SHA_SHORT-gts")
    BUILD_TAGS=("gts" "gts-$TIMESTAMP")
  elif [[ "$fedora_version" -eq "{{ latest }}" ]]; then
    COMMIT_TAGS=("$SHA_SHORT-latest")
    BUILD_TAGS=("latest" "latest-$TIMESTAMP")
  elif [[ "$fedora_version" -eq "{{ beta }}" ]]; then
    COMMIT_TAGS=("$SHA_SHORT-beta")
    BUILD_TAGS=("beta" "beta-$TIMESTAMP")
  fi

  COMMIT_TAGS+=("$SHA_SHORT-$fedora_version" "$fedora_version")
  BUILD_TAGS+=("$fedora_version" "$fedora_version-$TIMESTAMP")
  declare -A output
  output["BUILD_TAGS"]="${BUILD_TAGS[*]}"
  output["COMMIT_TAGS"]="${COMMIT_TAGS[*]}"
  output["TIMESTAMP"]="$TIMESTAMP"
  echo "${output[@]@K}"

# Verify Container with Cosign
[group('Utility')]
verify-container $container="" $registry="" $key="":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail

    # Defaults: fall back to local registry and public key
    : "${registry:={{ IMAGE_REGISTRY }}}"
    : "${key:=https://raw.githubusercontent.com/{{ org }}/{{ repo }}/main/cosign.pub}"

    # Verify Container using cosign public key
    if ! cosign verify --key "$key" "$registry/$container" >/dev/null; then
        echo '{{ style('error') }}NOTICE: Verification failed. Please ensure your public key is correct.{{ NORMAL }}' >&2
        exit 1
    fi

[group("Container")]
build-container $image_name="" $fedora_version="" $variant="" $github="":
  #!/usr/bin/env bash
  set ${SET_X:+-x} -eou pipefail

  {{ default-inputs }}
  {{ get-names }}
  {{ pull-retry }}

  SOURCE_IMAGE_DIGEST="$(yq -r ".images[] | select(.name == \"${source_image_name}-${fedora_version}\") | .digest" {{ image-file }})"

  # Verify Source Containers
  {{ just }} verify-container "$source_image_name@$SOURCE_IMAGE_DIGEST" "{{ source_registry }}" "https://raw.githubusercontent.com/nyahstack/fedora-toolboxes/main/cosign.pub"

  # Tags
  declare -A gen_tags="($({{ just }} gen-tags $image_name $fedora_version $variant))"
  if [[ "${github:-}" =~ pull_request ]]; then
    tags=(${gen_tags["COMMIT_TAGS"]})
  else
    tags=(${gen_tags["BUILD_TAGS"]})
  fi
  TIMESTAMP="${gen_tags["TIMESTAMP"]}"
  TAGS=()
  for tag in "${tags[@]}"; do
    TAGS+=("--tag" "localhost/$image_name:$tag")
  done

  CACHE_IMAGE="{{ IMAGE_REGISTRY }}/$image_name-cache-$fedora_version-$variant"
  CACHE_ARGS=("--layers" "--cache-from" "$CACHE_IMAGE")
  if [[ -n "${CI:-}" && ! "{{github}}" =~ pull_request ]]; then
    CACHE_ARGS+=("--cache-to" "$CACHE_IMAGE")
  fi

  # Labels
  VERSION="$fedora_version.$TIMESTAMP"
  LABELS=(
    "--label" "org.opencontainers.image.title=$image_name"
    "--label" "org.opencontainers.image.version=${VERSION}"
    "--label" "org.opencontainers.image.description=Devbox image for lair"
    "--label" "org.opencontainers.image.source=https://github.com/{{ org }}/{{ repo }}"
    "--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/{{ org }}/{{ repo }}/main/README.md"
  )

  # Build Arguments
  BUILD_ARGS=(
    "--build-arg" "IMAGE_NAME=${image_name%-*}"
    "--build-arg" "SOURCE_ORG={{ source_org }}"
    "--build-arg" "SOURCE_REGISTRY={{ source_registry }}"
    "--build-arg" "SOURCE_IMAGE=${source_image_name}"
    "--build-arg" "FEDORA_MAJOR_VERSION=$fedora_version"
    "--build-arg" "IMAGE_REGISTRY={{ IMAGE_REGISTRY }}"
    "--build-arg" "SOURCE_IMAGE_DIGEST=$SOURCE_IMAGE_DIGEST"
  )

  BUILD_SECRETS=()
  GITHUB_TOKEN_FILE=""
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    GITHUB_TOKEN_FILE="$(mktemp)"
    trap '[[ -n "${GITHUB_TOKEN_FILE:-}" ]] && rm -f "$GITHUB_TOKEN_FILE"' EXIT
    printf '%s' "$GITHUB_TOKEN" > "$GITHUB_TOKEN_FILE"
    chmod 600 "$GITHUB_TOKEN_FILE"
    BUILD_SECRETS+=("--secret" "id=GITHUB_TOKEN,src=$GITHUB_TOKEN_FILE")
  fi

  # Pull Image with retry
  pull-retry "{{ source_registry }}/$source_image_name:$fedora_version@$SOURCE_IMAGE_DIGEST"

  CACHE_IMAGE="{{ IMAGE_REGISTRY }}/$image_name-cache-$fedora_version"
  CACHE_ARGS=(
    "--layers"
    "--cache-from" "$CACHE_IMAGE"
  )
  if [[ -n "${CI:-}" && ! "${github:-}" =~ pull_request ]]; then
    CACHE_ARGS+=("--cache-to" "$CACHE_IMAGE")
  fi

  # Build Image
  {{ PODMAN }} build -f Containerfile "${CACHE_ARGS[@]}" "${BUILD_SECRETS[@]}" "${BUILD_ARGS[@]}" "${LABELS[@]}" "${TAGS[@]}"

  # CI Cleanup
  if [[ -n "${CI:-}" ]]; then
    {{ PODMAN }} rmi -f "{{ source_registry }}/$source_image_name:$fedora_version@$SOURCE_IMAGE_DIGEST"
  fi

# Login to GHCR
[group('CI')]
@login-to-ghcr $user $token:
    echo "$token" | {{ PODMAN }} login ghcr.io -u "$user" --password-stdin
    echo "$token" | docker login ghcr.io -u "$user" --password-stdin

# Push Images to Registry
[group('CI')]
push-to-registry $image_name $fedora_version $variant $destination="" $transport="":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    {{ get-names }}
    {{ build-missing }}

    : "${destination:={{ IMAGE_REGISTRY }}}"
    : "${transport:="docker://"}"

    declare -a TAGS="($({{ PODMAN }} image list localhost/$image_name:$fedora_version --noheading --format 'table {{{{ .Tag }}'))"
    for tag in "${TAGS[@]}"; do
        if {{ PODMAN }} manifest exists "localhost/$image_name:$tag-manifest"; then
            {{ PODMAN }} manifest rm "localhost/$image_name:$tag-manifest"
        fi
        {{ PODMAN }} manifest create "localhost/$image_name:$tag-manifest"
        {{ PODMAN }} manifest add "localhost/$image_name:$tag-manifest" "containers-storage:localhost/$image_name:$fedora_version"
        for i in {1..5}; do
            {{ PODMAN }} manifest push --compression-format=gzip --add-compression=zstd --add-compression=zstd:chunked "localhost/$image_name:$tag-manifest" "$transport$destination/$image_name:$tag" 2>&1 && break || sleep $((5 * i));
        done
    done

# Sign Images with Cosign
[group('CI')]
cosign-sign $image_name $fedora_version $variant $destination="":
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    {{ get-names }}
    {{ build-missing }}

    : "${destination:={{ IMAGE_REGISTRY }}}"
    digest="$(skopeo inspect docker://$destination/$image_name:$fedora_version --format '{{{{ .Digest }}')"
    cosign sign -y --key env://COSIGN_PRIVATE_KEY "$destination/$image_name@$digest"
