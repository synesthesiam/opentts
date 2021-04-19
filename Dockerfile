# -----------------------------------------------------------------------------
# Dockerfile for OpenTTS (https://github.com/synesthesiam/opentts)
# Requires Docker buildx: https://docs.docker.com/buildx/working-with-buildx/
# See scripts/build-docker.sh
#
# The IFDEF statements are handled by docker/preprocess.sh. These are just
# comments that are uncommented if the environment variable after the IFDEF is
# not empty.
#
# The build-docker.sh script will optionally add apt/pypi proxies running locally:
# * apt - https://docs.docker.com/engine/examples/apt-cacher-ng/ 
# * pypi - https://github.com/jayfk/docker-pypi-cache
# -----------------------------------------------------------------------------

FROM ubuntu:focal as build
ARG TARGETARCH
ARG TARGETVARIANT

ENV LANG C.UTF-8

# IFDEF APT_PROXY
#! RUN echo 'Acquire::http { Proxy "http://${APT_PROXY_HOST}:${APT_PROXY_PORT}"; };' >> /etc/apt/apt.conf.d/01proxy
# ENDIF

RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \
    apt-get install --yes --no-install-recommends \
        python3 python3-pip python3-venv \
        wget ca-certificates

# IFDEF PYPI_PROXY
#! ENV PIP_INDEX_URL=http://${PYPI_PROXY_HOST}:${PYPI_PROXY_PORT}/simple/
#! ENV PIP_TRUSTED_HOST=${PYPI_PROXY_HOST}
# ENDIF

COPY requirements.txt /app/
COPY scripts/create-venv.sh /app/scripts/

# Copy cache
COPY download/ /download/

# Install prebuilt nanoTTS
ENV NANOTTS_FILE=nanotts-20200520_${TARGETARCH}${TARGETVARIANT}.tar.gz

RUN if [ ! -f "/download/${NANOTTS_FILE}" ]; then \
        wget -O "/download/${NANOTTS_FILE}"  \
            --no-check-certificate \
            "https://github.com/synesthesiam/prebuilt-apps/releases/download/v1.0/${NANOTTS_FILE}"; \
    fi

RUN mkdir -p /nanotts && \
    tar -C /nanotts -xf "/download/${NANOTTS_FILE}"


# Install web server
ENV PIP_INSTALL='install -f /download'
RUN --mount=type=cache,target=/root/.cache/pip \
    cd /app && \
    export PIP_VERSION='pip<=20.2.4' && \
    scripts/create-venv.sh

# Delete extranous gruut data files
COPY gruut /gruut/
RUN mkdir -p /gruut && \
    cd /gruut && \
    find . -name lexicon.txt -delete

# -----------------------------------------------------------------------------
FROM ubuntu:focal as run
ARG LANGUAGE

ENV LANG C.UTF-8

# IFDEF APT_PROXY
#! RUN echo 'Acquire::http { Proxy "http://${APT_PROXY_HOST}:${APT_PROXY_PORT}"; };' >> /etc/apt/apt.conf.d/01proxy
# ENDIF

RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \ \
    apt-get install --yes --no-install-recommends \
        python3 python3-pip python3-venv \
        sox flite espeak-ng

RUN mkdir -p /app && echo "${LANGUAGE}" > /app/LANGUAGE

COPY etc/ /app/etc/
COPY scripts/install-packages.sh /app/
RUN /app/install-packages.sh "${LANGUAGE}"

# IFDEF APT_PROXY
#! RUN rm -f /etc/apt/apt.conf.d/01proxy
# ENDIF

# Copy nanotts
COPY --from=build /nanotts/ /usr/

# Copy virtual environment
COPY --from=build /app/ /app/

# Copy gruut data files
COPY --from=build /gruut/ /app/voices/larynx/gruut/

# Copy voices
COPY voices/ /app/voices/

# Run post-installation script
# May use files in /app/voices
COPY scripts/post-install.sh /app/
RUN /app/post-install.sh "${LANGUAGE}"

# Copy other files
COPY img/ /app/img/
COPY css/ /app/css/
COPY app.py tts.py swagger.yaml /app/
COPY templates/index.html /app/templates/

WORKDIR /app

EXPOSE 5500

ENTRYPOINT ["/app/.venv/bin/python3", "/app/app.py"]