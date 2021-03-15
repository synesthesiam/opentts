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

FROM ubuntu:focal
ARG TARGETARCH
ARG TARGETVARIANT

ENV LANG C.UTF-8

# IFDEF PROXY
#! RUN echo 'Acquire::http { Proxy "http://${APT_PROXY_HOST}:${APT_PROXY_PORT}"; };' >> /etc/apt/apt.conf.d/01proxy
# ENDIF

RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
        python3 python3-pip python3-venv \
        openjdk-8-jre-headless \
        sox wget ca-certificates \
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

# IFDEF PROXY
#! RUN rm -f /etc/apt/apt.conf.d/01proxy
# ENDIF

# Install prebuilt nanoTTS
RUN wget -O - --no-check-certificate \
    "https://github.com/synesthesiam/prebuilt-apps/releases/download/v1.0/nanotts-20200520_${TARGETARCH}${TARGETVARIANT}.tar.gz" | \
    tar -C /usr -xzf -

# IFDEF PROXY
#! ENV PIP_INDEX_URL=http://${PYPI_PROXY_HOST}:${PYPI_PROXY_PORT}/simple/
#! ENV PIP_TRUSTED_HOST=${PYPI_PROXY_HOST}
# ENDIF

COPY requirements.txt /app/
COPY scripts/create-venv.sh /app/scripts/

# Install web server
RUN cd /app && \
    scripts/create-venv.sh

# IFDEF PROXY
#! ENV PIP_INDEX_URL=''
#! ENV PIP_TRUSTED_HOST=''
# ENDIF

# Copy other files
COPY voices/ /app/voices/
COPY img/ /app/img/
COPY css/ /app/css/
COPY app.py tts.py swagger.yaml /app/
COPY templates/index.html /app/templates/

WORKDIR /app

EXPOSE 5500

ENTRYPOINT ["/app/.venv/bin/python3", "/app/app.py"]