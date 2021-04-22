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

FROM ubuntu:focal as python37

ENV LANG C.UTF-8

# IFDEF APT_PROXY
#! RUN echo 'Acquire::http { Proxy "http://${APT_PROXY_HOST}:${APT_PROXY_PORT}"; };' >> /etc/apt/apt.conf.d/01proxy
# ENDIF

RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
        build-essential \
        git zlib1g-dev patchelf rsync \
        libncursesw5-dev libreadline-gplv2-dev libssl-dev \
        libgdbm-dev libc6-dev libsqlite3-dev libbz2-dev libffi-dev \
        wget

COPY /download/ /download/

RUN if [ ! -f /download/Python-3.7.10.tar.xz ]; then \
      wget -O /download/Python-3.7.10.tar.xz 'https://www.python.org/ftp/python/3.7.10/Python-3.7.10.tar.xz'; \
    fi

RUN cd /download && \
    tar -xf Python-3.7.10.tar.xz && \
    cd Python-3.7.10 && \
    ./configure && \
    make -j4 && \
    make install DESTDIR=/app

# -----------------------------------------------------------------------------

FROM ubuntu:focal as build

ENV LANG C.UTF-8

# IFDEF APT_PROXY
#! RUN echo 'Acquire::http { Proxy "http://${APT_PROXY_HOST}:${APT_PROXY_PORT}"; };' >> /etc/apt/apt.conf.d/01proxy
# ENDIF

RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \
    apt-get install --yes --no-install-recommends \
        python3 build-essential \
        wget ca-certificates

# IFDEF PYPI_PROXY
#! ENV PIP_INDEX_URL=http://${PYPI_PROXY_HOST}:${PYPI_PROXY_PORT}/simple/
#! ENV PIP_TRUSTED_HOST=${PYPI_PROXY_HOST}
# ENDIF

COPY requirements.txt /app/
COPY scripts/create-venv.sh /app/scripts/

# Copy cache
COPY download/ /download/

COPY --from=python37 /app/ /app/
COPY --from=python37 /app/usr/local/include/python3.7m/ /usr/include/
ENV PYTHON=/app/usr/local/bin/python3

# Install Larynx
RUN --mount=type=cache,target=/root/.cache/pip \
    ${PYTHON} -m pip install --upgrade 'pip<=20.2.4' && \
    ${PYTHON} -m pip install --upgrade wheel setuptools && \
    ${PYTHON} -m pip install -f /download -r /app/requirements.txt

# Delete extranous gruut data files
COPY gruut /gruut/
RUN mkdir -p /gruut && \
    cd /gruut && \
    find . -name lexicon.txt -delete

# Install prebuilt nanoTTS
ARG TARGETARCH
ARG TARGETVARIANT
ENV NANOTTS_FILE=nanotts-20200520_${TARGETARCH}${TARGETVARIANT}.tar.gz

RUN if [ ! -f "/download/${NANOTTS_FILE}" ]; then \
        wget -O "/download/${NANOTTS_FILE}"  \
            --no-check-certificate \
            "https://github.com/synesthesiam/prebuilt-apps/releases/download/v1.0/${NANOTTS_FILE}"; \
    fi

RUN mkdir -p /nanotts && \
    tar -C /nanotts -xf "/download/${NANOTTS_FILE}"

# -----------------------------------------------------------------------------

FROM ubuntu:focal as run

ENV LANG C.UTF-8

# IFDEF APT_PROXY
#! RUN echo 'Acquire::http { Proxy "http://${APT_PROXY_HOST}:${APT_PROXY_PORT}"; };' >> /etc/apt/apt.conf.d/01proxy
# ENDIF

RUN apt-get update && \ \
    apt-get install --yes --no-install-recommends \
        sox flite espeak-ng \
        libssl1.1 libsqlite3-0 libatlas3-base libatomic1

# Install language-specific packages
ARG LANGUAGE
RUN mkdir -p /app && echo "${LANGUAGE}" > /app/LANGUAGE
COPY scripts/install-packages.sh /app/
RUN /app/install-packages.sh "${LANGUAGE}"

# Copy voices
COPY voices/ /app/voices/

# Copy nanotts
COPY --from=build /nanotts/ /usr/

# Copy gruut data files
COPY --from=build /gruut/ /app/voices/larynx/gruut/

# Copy virtual environment
COPY --from=build /app/ /app/

# Run post-installation script
# May use files in /app/voices, /app/etc, and python
COPY etc/ /app/etc/
COPY scripts/post-install.sh /app/
RUN /app/post-install.sh "${LANGUAGE}"

# IFDEF APT_PROXY
#! RUN rm -f /etc/apt/apt.conf.d/01proxy
# ENDIF

# Copy other files
COPY img/ /app/img/
COPY css/ /app/css/
COPY app.py tts.py swagger.yaml /app/
COPY templates/index.html /app/templates/

WORKDIR /app

EXPOSE 5500

ENTRYPOINT ["/app/usr/local/bin/python3", "/app/app.py"]
