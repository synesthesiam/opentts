# -----------------------------------------------------------------------------
# Dockerfile for OpenTTS (https://github.com/synesthesiam/opentts)
# Requires Docker buildx: https://docs.docker.com/buildx/working-with-buildx/
# See scripts/build-docker.sh
# -----------------------------------------------------------------------------

FROM ubuntu:focal as python37

ENV LANG C.UTF-8

RUN --mount=type=cache,id=apt-python,target=/var/apt/cache \
    apt-get update && \
    apt-get install --yes --no-install-recommends \
        build-essential \
        git zlib1g-dev patchelf rsync \
        libncursesw5-dev libreadline-gplv2-dev libssl-dev \
        libgdbm-dev libc6-dev libsqlite3-dev libbz2-dev libffi-dev \
        wget

COPY /download/source/ /download/

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

RUN --mount=type=cache,id=apt-build,target=/var/apt/cache \
    apt-get update && \
    apt-get install --yes --no-install-recommends \
        python3 build-essential \
        wget ca-certificates

COPY --from=python37 /app/ /app/
COPY --from=python37 /app/usr/local/include/python3.7m/ /usr/include/
ENV PYTHON=/app/usr/local/bin/python3

# Copy cache
COPY download/ /download/

COPY requirements.txt /app/
COPY scripts/create-venv.sh /app/scripts/

# Install Larynx
RUN --mount=type=cache,id=pip-build,target=/root/.cache/pip \
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

RUN --mount=type=cache,id=apt-run,target=/var/apt/cache \
    apt-get update && \
    apt-get install --yes --no-install-recommends \
        sox flite espeak-ng \
        libssl1.1 libsqlite3-0 libatlas3-base libatomic1

# Copy nanotts
COPY --from=build /nanotts/ /usr/

# Copy virtual environment
COPY --from=build /app/ /app/

# Install optional packages
# IFDEF INSTALL_FESTIVAL
# RUN --mount=type=cache,id=apt-run,target=/var/apt/cache \
      apt-get install --yes --no-install-recommends \
        festival
# ENDIF

# IFDEF INSTALL_JAVA
# RUN --mount=type=cache,id=apt-run,target=/var/apt/cache \
      apt-get install --yes --no-install-recommends \
        openjdk-11-jre-headless
# ENDIF

# IFDEF INSTALL_LARYNX
# RUN --mount=type=cache,id=apt-run,target=/var/apt/cache \
      apt-get install --yes --no-install-recommends \
        libopenblas-base libgomp1
# ENDIF

# Install language-specific packages
# IFDEF LANGUAGE_CA
# RUN --mount=type=cache,id=apt-run,target=/var/apt/cache \
      apt-get install --yes --no-install-recommends \
        festvox-ca-ona-hts
# ENDIF

# IFDEF LANGUAGE_CS
# RUN --mount=type=cache,id=apt-run,target=/var/apt/cache \
      apt-get install --yes --no-install-recommends \
        festvox-czech-dita festvox-czech-krb festvox-czech-machac festvox-czech-ph
# ENDIF

# IFDEF LANGUAGE_EN
# RUN --mount=type=cache,id=apt-run,target=/var/apt/cache \
      apt-get install --yes --no-install-recommends \
        festvox-don festvox-en1 festvox-kallpc16k festvox-kdlpc16k festvox-rablpc16k festvox-us1 festvox-us2 festvox-us3 festvox-us-slt-hts
# ENDIF

# IFDEF LANGUAGE_ES
# RUN --mount=type=cache,id=apt-run,target=/var/apt/cache \
      apt-get install --yes --no-install-recommends \
        festvox-ellpc11k
# ENDIF

# IFDEF LANGUAGE_FI
# RUN --mount=type=cache,id=apt-run,target=/var/apt/cache \
      apt-get install --yes --no-install-recommends \
        festvox-suopuhe-lj festvox-suopuhe-mv
# ENDIF

# IFDEF LANGUAGE_HI
# RUN --mount=type=cache,id=apt-run,target=/var/apt/cache \
      apt-get install --yes --no-install-recommends \
        festvox-hi-nsk
# ENDIF

# IFDEF LANGUAGE_IT
# RUN --mount=type=cache,id=apt-run,target=/var/apt/cache \
      apt-get install --yes --no-install-recommends \
        patch festvox-italp16k festvox-itapc16k
# ENDIF

# IFDEF LANGUAGE_MR
# RUN --mount=type=cache,id=apt-run,target=/var/apt/cache \
      apt-get install --yes --no-install-recommends \
        festvox-mr-nsk
# ENDIF

# IFDEF LANGUAGE_RU
# RUN --mount=type=cache,id=apt-run,target=/var/apt/cache \
      apt-get install --yes --no-install-recommends \
        festvox-ru
# ENDIF

# IFDEF LANGUAGE_TE
# RUN --mount=type=cache,id=apt-run,target=/var/apt/cache \
      apt-get install --yes --no-install-recommends \
        festvox-te-nsk
# ENDIF

# Copy voices
COPY voices/ /app/voices/

# Copy gruut data files
COPY --from=build /gruut/ /app/voices/larynx/gruut/

# Do post-installation
# May use files in /app/voices, /app/etc, and python
COPY etc/ /app/etc/

# IFDEF LANGUAGE_AR
# RUN --mount=type=cache,id=pip-run,target=/root/.cache/pip \
      /app/usr/local/bin/python3 -m pip install \
        'mishkal~=0.4.0' 'codernitydb3'
# RUN cp /app/voices/festival/ar/languages/language_arabic.scm /usr/share/festival/languages/ && \
      mkdir -p /usr/share/festival/voices/arabic && \
      cp -r /app/voices/festival/ar/voices/ara_norm_ziad_hts /usr/share/festival/voices/arabic/
# ENDIF

# IFDEF LANGUAGE_IT
# RUN patch -d /usr/share -p1 < /app/etc/03_fix_return_utt_synth_types.patch
# ENDIF

# Copy other files
COPY img/ /app/img/
COPY css/ /app/css/
COPY app.py tts.py swagger.yaml /app/
COPY templates/index.html /app/templates/

# Need python3 in PATH for phonetisaurus
ENV PATH=/app/usr/local/bin:${PATH}

WORKDIR /app

EXPOSE 5500

ENTRYPOINT ["/app/usr/local/bin/python3", "/app/app.py"]
