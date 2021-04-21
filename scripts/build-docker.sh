#!/usr/bin/env bash
set -e

# Directory of *this* script
this_dir="$( cd "$( dirname "$0" )" && pwd )"
src_dir="$(realpath "${this_dir}/..")"

version="$(cat "${src_dir}/VERSION")"

# -----------------------------------------------------------------------------

: "${PLATFORMS=linux/amd64,linux/arm/v7,linux/arm64}"
: "${DOCKER_REGISTRY=docker.io}"

: "${LANGUAGE=en}"
# ar (Arabic)
# bn (Bengali)
# ca (Catalan)
# cs (Czech)
# de (German)
# en (English)
# es (Spanish)
# fi (Finnish)
# fr (French)
# gu (Gujarati)
# hi (Hindi)
# it (Italian)
# kn (Kannada)
# mr (Marathi)
# nl (Dutch)
# pa (Punjabi)
# ru (Russian)
# sv (Swedish)
# ta (Tamil)
# te (Telugu)
# tr (Turkish)

DOCKERFILE="${src_dir}/Dockerfile"

if [[ -n "${PROXY}" ]]; then
    if [[ -z "${PROXY_HOST}" ]]; then
        export PROXY_HOST="$(hostname -I | awk '{print $1}')"
    fi

    : "${APT_PROXY_HOST=${PROXY_HOST}}"
    : "${APT_PROXY_PORT=3142}"
    : "${PYPI_PROXY_HOST=${PROXY_HOST}}"
    : "${PYPI_PROXY_PORT=4000}"

    if [[ -z "NO_APT_PROXY" ]]; then
        export APT_PROXY='1'
        export APT_PROXY_HOST
        export APT_PROXY_PORT
        echo "APT proxy: ${APT_PROXY_HOST}:${APT_PROXY_PORT}"
    fi

    if [[ -z "NO_PYPI_PROXY" ]]; then
        export PYPI_PROXY='1'
        export PYPI_PROXY_HOST
        export PYPI_PROXY_PORT
        echo "PyPI proxy: ${PYPI_PROXY_HOST}:${PYPI_PROXY_PORT}"
    fi

    # Use temporary file instead
    temp_dockerfile="$(mktemp -p "${src_dir}")"
    function cleanup {
        rm -f "${temp_dockerfile}"
    }

    trap cleanup EXIT

    # Run through pre-processor to replace variables
    "${src_dir}/docker/preprocess.sh" < "${DOCKERFILE}" > "${temp_dockerfile}"
    DOCKERFILE="${temp_dockerfile}"
fi

# Write .dockerignore file
DOCKERIGNORE="${src_dir}/.dockerignore"
cp -f "${src_dir}/.dockerignore.in" "${DOCKERIGNORE}"

# Determine voice paths to keep in Docker image
MARYTTS_JARS=('voices/marytts/lib')
LARYNX_VOCODERS=('voices/larynx/hifi_gan' 'voices/larynx/waveglow')

keep_paths=()
tags=("--tag" "${DOCKER_REGISTRY}/synesthesiam/opentts:${LANGUAGE}")

if [[ "${LANGUAGE}" == 'ar' ]]; then
    # Arabic
    keep_paths+=('voices/festival/ar')
elif [[ "${LANGUAGE}" == 'bn' ]]; then
    # Bengali
    keep_paths+=('voices/flite/cmu_indic_ben_rm.flitevox')
elif [[ "${LANGUAGE}" == 'ca' ]]; then
    # Catalan
    # Packages: festvox-ca-ona-hts
    :
elif [[ "${LANGUAGE}" == 'cs' ]]; then
    # Czech
    # Packages: festvox-czech-dita festvox-czech-krb festvox-czech-machac festvox-czech-ph
    :
elif [[ "${LANGUAGE}" == 'de' ]]; then
    # German
    keep_paths+=('voices/marytts/de' ${MARYTTS_JARS})
    keep_paths+=('gruut/de-de' 'voices/larynx/de-de' ${LARYNX_VOCODERS[@]})
elif [[ "${LANGUAGE}" == 'en' ]]; then
    # English
    # Packages: festvox-don festvox-en1 festvox-kallpc16k festvox-kdlpc16k festvox-rablpc16k festvox-us1 festvox-us2 festvox-us3 festvox-us-slt-hts
    keep_paths+=('voices/marytts/en-GB' 'voices/marytts/en-US' ${MARYTTS_JARS})
    keep_paths+=('voices/larynx/en-us' ${LARYNX_VOCODERS[@]})

    # Use latest tag for English
    tags+=("--tag" "${DOCKER_REGISTRY}/synesthesiam/opentts:latest")
elif [[ "${LANGUAGE}" == 'es' ]]; then
    # Spanish
    # Packages: festvox-ellpc11k
    keep_paths+=('gruut/es-es' 'voices/larynx/es-es' ${LARYNX_VOCODERS[@]})
elif [[ "${LANGUAGE}" == 'fi' ]]; then
    # Finish
    # Packages: festvox-suopuhe-lj festvox-suopuhe-mv
    :
elif [[ "${LANGUAGE}" == 'fr' ]]; then
    # French
    keep_paths+=('voices/marytts/fr' ${MARYTTS_JARS})
    keep_paths+=('gruut/fr-fr' 'voices/larynx/fr-fr' ${LARYNX_VOCODERS[@]})
elif [[ "${LANGUAGE}" == 'gu' ]]; then
    # Gujarati
    keep_paths+=('voices/flite/cmu_indic_guj_ad.flitevox' 'voices/flite/cmu_indic_guj_dp.flitevox' 'voices/flite/cmu_indic_guj_kt.flitevox')
elif [[ "${LANGUAGE}" == 'hi' ]]; then
    # Hindi
    # Packages: festvox-hi-nsk
    keep_paths+=('voices/flite/cmu_indic_hin_ab.flitevox')
elif [[ "${LANGUAGE}" == 'it' ]]; then
    # Italian
    # Packages: festvox-italp16k festvox-itapc16k
    keep_paths+=('voices/marytts/it' ${MARYTTS_JARS})
    keep_paths+=('gruut/it-it' 'voices/larynx/it-it' ${LARYNX_VOCODERS[@]})
elif [[ "${LANGUAGE}" == 'kn' ]]; then
    # Kannada
    keep_paths+=('voices/flite/cmu_indic_kan_plv.flitevox')
elif [[ "${LANGUAGE}" == 'mr' ]]; then
    # Marathi
    # Packages: festvox-mr-nsk
    keep_paths+=('voices/flite/cmu_indic_mar_aup.flitevox' 'voices/flite/cmu_indic_mar_slp.flitevox')
elif [[ "${LANGUAGE}" == 'nl' ]]; then
    # Dutch
    keep_paths+=('gruut/nl' 'voices/larynx/nl' ${LARYNX_VOCODERS[@]})
elif [[ "${LANGUAGE}" == 'pa' ]]; then
    # Punjabi
    keep_paths+=('voices/flite/cmu_indic_pan_amp.flitevox')
elif [[ "${LANGUAGE}" == 'ru' ]]; then
    # Russian
    # Packages: festvox-ru
    keep_paths+=('voices/marytts/ru' ${MARYTTS_JARS})
    keep_paths+=('gruut/ru-ru' 'voices/larynx/ru-ru' ${LARYNX_VOCODERS[@]})
elif [[ "${LANGUAGE}" == 'sv' ]]; then
    # Swedish
    keep_paths+=('voices/marytts/sv' ${MARYTTS_JARS})
    keep_paths+=('gruut/sv-se' 'voices/larynx/sv-se' ${LARYNX_VOCODERS[@]})
elif [[ "${LANGUAGE}" == 'ta' ]]; then
    # Tamil
    keep_paths+=('voices/flite/cmu_indic_tam_sdr.flitevox')
elif [[ "${LANGUAGE}" == 'te' ]]; then
    # Telugu
    # Packages: festvox-te-nsk
    keep_paths+=('voices/marytts/te' ${MARYTTS_JARS})
    keep_paths+=('voices/flite/cmu_indic_tel_kpn.flitevox' 'voices/flite/cmu_indic_tel_sk.flitevox' 'voices/flite/cmu_indic_tel_ss.flitevox')
elif [[ "${LANGUAGE}" == 'tr' ]]; then
    # Turkish
    keep_paths+=('voices/marytts/tr' ${MARYTTS_JARS})
else
    echo "Unknown language: ${LANGUAGE}" >&2
    exit 1
fi

for keep_path in "${keep_paths[@]}"; do
    echo "!${keep_path}" >> "${DOCKERIGNORE}"
done

# -----------------------------------------------------------------------------

if [[ -n "${NOBUILDX}" ]]; then
    # Don't use docker buildx (single platform)

    if [[ -z "${TARGETARCH}" ]]; then
        # Guess architecture
        cpu_arch="$(uname -m)"
        case "${cpu_arch}" in
            armv6l)
                export TARGETARCH=arm
                export TARGETVARIANT=v6
                ;;

            armv7l)
                export TARGETARCH=arm
                export TARGETVARIANT=v7
                ;;

            aarch64|arm64v8)
                export TARGETARCH=arm64
                export TARGETVARIANT=''
                ;;

            *)
                # Assume x86_64
                export TARGETARCH=amd64
                export TARGETVARIANT=''
                ;;
        esac

        echo "Guessed architecture: ${TARGETARCH}${TARGETVARIANT}"
    fi

    docker build \
        "${src_dir}" \
        -f "${DOCKERFILE}" \
        --build-arg "TARGETARCH=${TARGETARCH}" \
        --build-arg "TARGETVARIANT=${TARGETVARIANT}" \
        --build-arg "LANGUAGE=${LANGUAGE}" \
        "${tags[@]}" \
        "$@"
else
    # Use docker buildx (multi-platform)
    docker buildx build \
           "${src_dir}" \
           -f "${DOCKERFILE}" \
           "--platform=${PLATFORMS}" \
           --build-arg "LANGUAGE=${LANGUAGE}" \
           "${tags[@]}" \
           --push \
           "$@"
fi
