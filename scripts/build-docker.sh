#!/usr/bin/env bash
set -e

# Directory of *this* script
this_dir="$( cd "$( dirname "$0" )" && pwd )"
src_dir="$(realpath "${this_dir}/..")"

version="$(cat "${src_dir}/VERSION")"

languages=()
if [[ -n "$1" ]]; then
    # Specific languages
    while [[ -n "$1" ]]; do
        languages+=("$1")
        shift 1
    done
else
    # All languages
    languages+=('ar' 'bn' 'ca' 'cs' 'de' 'el' 'en' 'es' 'fi' 'fr' 'gu' 'hi' 'hu' 'it' 'ja' 'kn' 'ko' 'mr' 'nl' 'pa' 'ru' 'sv' 'sw' 'ta' 'te' 'tr' 'zh')
fi


# -----------------------------------------------------------------------------

: "${DOCKER_PLATFORMS=--platform linux/amd64,linux/arm/v7,linux/arm64}"
: "${DOCKER_PUSH=--push}"
: "${DOCKER_REGISTRY=docker.io}"

if [[ -n "${DOCKER_REGISTRY}" ]] && [[ "${DOCKER_REGISTRY}" != */ ]]; then
    # Add final slash
    DOCKER_REGISTRY="${DOCKER_REGISTRY}/"
fi

for language in ${languages[@]};
do
    echo "Language: ${language}"

    tags=("--tag" "${DOCKER_REGISTRY}synesthesiam/opentts:${language}")
    tags+=("--tag" "${DOCKER_REGISTRY}synesthesiam/opentts:${language}-${version}")

    if [[ "${language}" == 'en' ]]; then
        tags+=("--tag" "${DOCKER_REGISTRY}synesthesiam/opentts:latest")
    fi

    bash "${src_dir}/configure" --language "${language}"


	xargs < .dockerargs \
        docker buildx build "${src_dir}" \
        ${tags[@]} ${DOCKER_PLATFORMS} ${DOCKER_PUSH}
done

echo 'Done'
