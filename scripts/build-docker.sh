#!/usr/bin/env bash
set -e

# Directory of *this* script
this_dir="$( cd "$( dirname "$0" )" && pwd )"
src_dir="$(realpath "${this_dir}/..")"

version="$(cat "${src_dir}/VERSION")"

# -----------------------------------------------------------------------------

: "${PLATFORMS=linux/amd64,linux/arm/v7,linux/arm64}"
: "${DOCKER_REGISTRY=docker.io}"

if [[ -n "${DOCKER_REGISTRY}" ]] && [[ "${DOCKER_REGISTRY}" != */ ]]; then
    # Add final slash
    DOCKER_REGISTRY="${DOCKER_REGISTRY}/"
fi

: "${OPENTTS_LANG=en}"
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
# sw (Swahili)
# ta (Tamil)
# te (Telugu)
# tr (Turkish)

echo "Language: ${OPENTTS_LANG}"

# -----------------------------------------------------------------------------

DOCKERFILE="${src_dir}/Dockerfile"

# Write .dockerignore file
DOCKERIGNORE="${src_dir}/.dockerignore"
cp -f "${src_dir}/.dockerignore.in" "${DOCKERIGNORE}"

# Determine voice paths to keep in Docker image
MARYTTS_JARS=('voices/marytts/lib')
LARYNX_VOCODERS=('voices/larynx/hifi_gan' 'voices/larynx/waveglow')

keep_paths=()
tags=("--tag" "${DOCKER_REGISTRY}synesthesiam/opentts:${OPENTTS_LANG}")
tags+=("--tag" "${DOCKER_REGISTRY}synesthesiam/opentts:${OPENTTS_LANG}-${version}")

# Extra package variables
# INSTALL_FESTIVAL
# INSTALL_JAVA
# INSTALL_LARYNX

if [[ "${OPENTTS_LANG}" == 'ar' ]]; then
    # Arabic
    export LANGUAGE_AR='1'
    export INSTALL_FESTIVAL='1'
    keep_paths+=('voices/festival/ar')
elif [[ "${OPENTTS_LANG}" == 'bn' ]]; then
    # Bengali
    export LANGUAGE_BN='1'
    keep_paths+=('voices/flite/cmu_indic_ben_rm.flitevox')
elif [[ "${OPENTTS_LANG}" == 'ca' ]]; then
    # Catalan
    export LANGUAGE_CA='1'
    export INSTALL_FESTIVAL='1'
    # Packages: festvox-ca-ona-hts
    :
elif [[ "${OPENTTS_LANG}" == 'cs' ]]; then
    # Czech
    export LANGUAGE_CS='1'
    export INSTALL_FESTIVAL='1'
    # Packages: festvox-czech-dita festvox-czech-krb festvox-czech-machac festvox-czech-ph
    :
elif [[ "${OPENTTS_LANG}" == 'de' ]]; then
    # German
    export LANGUAGE_DE='1'
    export INSTALL_FESTIVAL='1'
    export INSTALL_JAVA='1'
    export INSTALL_LARYNX='1'
    keep_paths+=('voices/marytts/de' ${MARYTTS_JARS})
    keep_paths+=('gruut/de-de' 'voices/larynx/de-de' ${LARYNX_VOCODERS[@]})
elif [[ "${OPENTTS_LANG}" == 'en' ]]; then
    # English
    export LANGUAGE_EN='1'
    export INSTALL_FESTIVAL='1'
    export INSTALL_JAVA='1'
    export INSTALL_LARYNX='1'
    # Packages: festvox-don festvox-en1 festvox-kallpc16k festvox-kdlpc16k festvox-rablpc16k festvox-us1 festvox-us2 festvox-us3 festvox-us-slt-hts
    keep_paths+=('voices/marytts/en-GB' 'voices/marytts/en-US' ${MARYTTS_JARS})
    keep_paths+=('voices/larynx/en-us' ${LARYNX_VOCODERS[@]})

    # Use latest tag for English
    tags+=("--tag" "${DOCKER_REGISTRY}synesthesiam/opentts:latest")
    tags+=("--tag" "${DOCKER_REGISTRY}synesthesiam/opentts:${version}")
elif [[ "${OPENTTS_LANG}" == 'es' ]]; then
    # Spanish
    export LANGUAGE_ES='1'
    export INSTALL_FESTIVAL='1'
    export INSTALL_LARYNX='1'
    # Packages: festvox-ellpc11k
    keep_paths+=('gruut/es-es' 'voices/larynx/es-es' ${LARYNX_VOCODERS[@]})
elif [[ "${OPENTTS_LANG}" == 'fi' ]]; then
    # Finish
    export LANGUAGE_FI='1'
    export INSTALL_FESTIVAL='1'
    # Packages: festvox-suopuhe-lj festvox-suopuhe-mv
    :
elif [[ "${OPENTTS_LANG}" == 'fr' ]]; then
    # French
    export LANGUAGE_FR='1'
    export INSTALL_JAVA='1'
    export INSTALL_LARYNX='1'
    keep_paths+=('voices/marytts/fr' ${MARYTTS_JARS})
    keep_paths+=('gruut/fr-fr' 'voices/larynx/fr-fr' ${LARYNX_VOCODERS[@]})
elif [[ "${OPENTTS_LANG}" == 'gu' ]]; then
    # Gujarati
    export LANGUAGE_GU='1'
    keep_paths+=('voices/flite/cmu_indic_guj_ad.flitevox' 'voices/flite/cmu_indic_guj_dp.flitevox' 'voices/flite/cmu_indic_guj_kt.flitevox')
elif [[ "${OPENTTS_LANG}" == 'hi' ]]; then
    # Hindi
    export LANGUAGE_HI='1'
    export INSTALL_FESTIVAL='1'
    # Packages: festvox-hi-nsk
    keep_paths+=('voices/flite/cmu_indic_hin_ab.flitevox')
elif [[ "${OPENTTS_LANG}" == 'it' ]]; then
    # Italian
    export LANGUAGE_IT='1'
    export INSTALL_FESTIVAL='1'
    export INSTALL_JAVA='1'
    export INSTALL_LARYNX='1'
    # Packages: festvox-italp16k festvox-itapc16k
    keep_paths+=('voices/marytts/it' ${MARYTTS_JARS})
    keep_paths+=('gruut/it-it' 'voices/larynx/it-it' ${LARYNX_VOCODERS[@]})
elif [[ "${OPENTTS_LANG}" == 'kn' ]]; then
    # Kannada
    export LANGUAGE_BN='1'
    keep_paths+=('voices/flite/cmu_indic_kan_plv.flitevox')
elif [[ "${OPENTTS_LANG}" == 'mr' ]]; then
    # Marathi
    export LANGUAGE_MR='1'
    export INSTALL_FESTIVAL='1'
    # Packages: festvox-mr-nsk
    keep_paths+=('voices/flite/cmu_indic_mar_aup.flitevox' 'voices/flite/cmu_indic_mar_slp.flitevox')
elif [[ "${OPENTTS_LANG}" == 'nl' ]]; then
    # Dutch
    export LANGUAGE_NL='1'
    export INSTALL_LARYNX='1'
    keep_paths+=('gruut/nl' 'voices/larynx/nl' ${LARYNX_VOCODERS[@]})
elif [[ "${OPENTTS_LANG}" == 'pa' ]]; then
    # Punjabi
    export LANGUAGE_PA='1'
    keep_paths+=('voices/flite/cmu_indic_pan_amp.flitevox')
elif [[ "${OPENTTS_LANG}" == 'ru' ]]; then
    # Russian
    export LANGUAGE_RU='1'
    export INSTALL_FESTIVAL='1'
    export INSTALL_JAVA='1'
    export INSTALL_LARYNX='1'
    # Packages: festvox-ru
    keep_paths+=('voices/marytts/ru' ${MARYTTS_JARS})
    keep_paths+=('gruut/ru-ru' 'voices/larynx/ru-ru' ${LARYNX_VOCODERS[@]})
elif [[ "${OPENTTS_LANG}" == 'sv' ]]; then
    # Swedish
    export LANGUAGE_SV='1'
    export INSTALL_JAVA='1'
    export INSTALL_LARYNX='1'
    keep_paths+=('voices/marytts/sv' ${MARYTTS_JARS})
    keep_paths+=('gruut/sv-se' 'voices/larynx/sv-se' ${LARYNX_VOCODERS[@]})
elif [[ "${OPENTTS_LANG}" == 'ta' ]]; then
    # Tamil
    export LANGUAGE_TA='1'
    keep_paths+=('voices/flite/cmu_indic_tam_sdr.flitevox')
elif [[ "${OPENTTS_LANG}" == 'te' ]]; then
    # Telugu
    export LANGUAGE_TE='1'
    export INSTALL_FESTIVAL='1'
    export INSTALL_JAVA='1'
    # Packages: festvox-te-nsk
    keep_paths+=('voices/marytts/te' ${MARYTTS_JARS})
    keep_paths+=('voices/flite/cmu_indic_tel_kpn.flitevox' 'voices/flite/cmu_indic_tel_sk.flitevox' 'voices/flite/cmu_indic_tel_ss.flitevox')
elif [[ "${OPENTTS_LANG}" == 'tr' ]]; then
    # Turkish
    export LANGUAGE_TR='1'
    export INSTALL_JAVA='1'
    keep_paths+=('voices/marytts/tr' ${MARYTTS_JARS})
else
    echo "Unknown language: ${OPENTTS_LANG}" >&2
    exit 1
fi

for keep_path in "${keep_paths[@]}"; do
    echo "!${keep_path}" >> "${DOCKERIGNORE}"
done

# -----------------------------------------------------------------------------

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
fi

# Use temporary Dockerfile
temp_dockerfile="$(mktemp -p "${src_dir}")"
function cleanup {
    rm -f "${temp_dockerfile}"
}

trap cleanup EXIT

# Run through pre-processor to replace variables
"${src_dir}/docker/preprocess.sh" < "${DOCKERFILE}" > "${temp_dockerfile}"
DOCKERFILE="${temp_dockerfile}"

# -----------------------------------------------------------------------------

if [[ -n "${NOBUILDX}" ]]; then
    # Don't use docker buildx (single platform)

    if [[ -z "${TARGETARCH}" ]]; then
        # Guess architecture
        cpu_arch="$(uname -m)"
        case "${cpu_arch}" in
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
        --build-arg "OPENTTS_LANG=${OPENTTS_LANG}" \
        "${tags[@]}" \
        "$@"
else
    args=()

    if [[ -n "${DOCKER_REGISTRY}" ]]; then
        args+=('--push')
    fi

    args+=("$@")

    # Use docker buildx (multi-platform)
    docker buildx build \
           "${src_dir}" \
           -f "${DOCKERFILE}" \
           "--platform=${PLATFORMS}" \
           --build-arg "OPENTTS_LANG=${OPENTTS_LANG}" \
           "${tags[@]}" \
           "${args[@]}"
fi
