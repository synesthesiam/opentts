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

RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
        wget ca-certificates \
        build-essential \
        git zlib1g-dev patchelf rsync \
        libncursesw5-dev libreadline-gplv2-dev libssl-dev \
        libgdbm-dev libc6-dev libsqlite3-dev libbz2-dev libffi-dev

# Install prebuilt nanoTTS
RUN mkdir -p /nanotts && \
    wget -O - --no-check-certificate \
        "https://github.com/synesthesiam/prebuilt-apps/releases/download/v1.0/nanotts-20200520_${TARGETARCH}${TARGETVARIANT}.tar.gz" | \
        tar -C /nanotts -xzf -

# IFDEF PYPI_PROXY
#! ENV PIP_INDEX_URL=http://${PYPI_PROXY_HOST}:${PYPI_PROXY_PORT}/simple/
#! ENV PIP_TRUSTED_HOST=${PYPI_PROXY_HOST}
# ENDIF

COPY requirements.txt /app/
COPY scripts/create-venv.sh /app/scripts/

# Copy wheel cache
COPY download/ /download/

# -----------------------------------------------------------------------------

# Build Python 3.7
RUN if [ ! -f /download/Python-3.7.10.tar.xz ]; then \
        wget -O /download/Python-3.7.10.tar.xz 'https://www.python.org/ftp/python/3.7.10/Python-3.7.10.tar.xz'; \
    fi && \
    mkdir -p /build && \
    tar -C /build -xf /download/Python-3.7.10.tar.xz

RUN cd /build/Python-3.7.10 && \
    ./configure && \
    make -j 4 && \
    make install DESTDIR=/python

# -----------------------------------------------------------------------------

# Install web server
ENV PIP_INSTALL='install -f /download'
RUN cd /app && \
    export PYTHON=/python/usr/local/bin/python3.7 && \
    export PIP_VERSION='pip<=20.2.4' && \
    scripts/create-venv.sh

# Delete extranous gruut data files
RUN mkdir -p /gruut && \
    cd /gruut && \
    find . -name lexicon.txt -delete

# -----------------------------------------------------------------------------

FROM ubuntu:focal as run

ENV LANG C.UTF-8

# IFDEF APT_PROXY
#! RUN echo 'Acquire::http { Proxy "http://${APT_PROXY_HOST}:${APT_PROXY_PORT}"; };' >> /etc/apt/apt.conf.d/01proxy
# ENDIF

RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
        openjdk-11-jre-headless \
        sox \
        libopenblas-base libgomp1 libatomic1 \
        flite espeak-ng festival \
        festvox-ca-ona-hts \
        festvox-czech-dita \
        festvox-czech-krb \
        festvox-czech-machac \
        festvox-czech-ph \
        festvox-don \
        festvox-ellpc11k \
        festvox-en1 \
        festvox-kallpc16k \
        festvox-kdlpc16k \
        festvox-rablpc16k \
        festvox-us1 \
        festvox-us2 \
        festvox-us3 \
        festvox-us-slt-hts \
        festvox-ru \
        festvox-suopuhe-lj \
        festvox-suopuhe-mv

# IFDEF APT_PROXY
#! RUN rm -f /etc/apt/apt.conf.d/01proxy
# ENDIF

# Copy nanotts
COPY --from=build /nanotts/ /usr/

# Copy Python 3.7
COPY --from=build /python/ /python/

# Copy virtual environment
COPY --from=build /app/ /app/

# Copy gruut data files
COPY --from=build /gruut/ /app/voices/larynx/gruut/

# Copy other files
COPY voices/ /app/voices/
COPY img/ /app/img/
COPY css/ /app/css/
COPY app.py tts.py swagger.yaml /app/
COPY templates/index.html /app/templates/

WORKDIR /app

EXPOSE 5500

ENTRYPOINT ["/python/usr/local/bin/python3.7", "/app/app.py"]
