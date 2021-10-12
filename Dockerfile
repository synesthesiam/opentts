# -----------------------------------------------------------------------------
# Dockerfile for OpenTTS (https://github.com/synesthesiam/opentts)
# Requires Docker buildx: https://docs.docker.com/buildx/working-with-buildx/
# -----------------------------------------------------------------------------

FROM debian:bullseye as build
ARG TARGETARCH
ARG TARGETVARIANT

ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

RUN echo "Dir::Cache var/cache/apt/${TARGETARCH}${TARGETVARIANT};" > /etc/apt/apt.conf.d/01cache
RUN --mount=type=cache,id=apt-build,target=/var/cache/apt \
    mkdir -p /var/cache/apt/${TARGETARCH}${TARGETVARIANT}/archives/partial && \
    apt-get update && \
    apt-get install --yes --no-install-recommends \
        build-essential python3 python3-venv python3-dev

# Clean up
RUN rm -f /etc/apt/apt.conf.d/01cache

WORKDIR /app

# Create virtual environment
RUN --mount=type=cache,id=pip-venv,target=/root/.cache/pip \
    python3 -m venv .venv && \
    .venv/bin/pip3 install --upgrade pip && \
    .venv/bin/pip3 install --upgrade wheel setuptools

COPY download/ /download/

COPY requirements.txt /requirements.txt

RUN --mount=type=cache,id=pip-requirements,target=/root/.cache/pip \
    .venv/bin/pip3 install -f /download -r /requirements.txt

COPY python_packages /python_packages
RUN --mount=type=cache,id=pip-extras,target=/root/.cache/pip \
    if [ -s /python_packages ]; then \
    cat /python_packages | xargs .venv/bin/pip3 install \
    -f /download \
    -f 'https://download.pytorch.org/whl/cpu/torch_stable.html' \
    -f 'https://synesthesiam.github.io/prebuilt-apps/' ; \
    fi

# -----------------------------------------------------------------------------

FROM debian:bullseye as run
ARG TARGETARCH
ARG TARGETVARIANT

ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

COPY packages /packages

RUN echo 'deb http://deb.debian.org/debian bullseye contrib non-free' > /etc/apt/sources.list.d/contrib.list

RUN echo "Dir::Cache var/cache/apt/${TARGETARCH}${TARGETVARIANT};" > /etc/apt/apt.conf.d/01cache
RUN --mount=type=cache,id=apt-run,target=/var/cache/apt \
    mkdir -p /var/cache/apt/${TARGETARCH}${TARGETVARIANT}/archives/partial && \
    apt-get update && \
    cat /packages | xargs apt-get install --yes --no-install-recommends

RUN useradd -ms /bin/bash opentts

# Copy virtual environment and files
COPY voices/ /home/opentts/app/voices/
COPY --from=build /app/.venv /home/opentts/app/.venv
COPY css/ /home/opentts/app/css/
COPY img/ /home/opentts/app/img/
COPY js/ /home/opentts/app/js/
COPY templates/ /home/opentts/app/templates/
COPY glow_speak/ /home/opentts/app/glow_speak/
COPY larynx/ /home/opentts/app/larynx/
COPY app.py tts.py /home/opentts/app/

ARG DEFAULT_LANGUAGE='en'
RUN echo "${DEFAULT_LANGUAGE}" > /home/opentts/app/LANGUAGE

# Post-installation
RUN if [ -d '/usr/share/festival' ] && [ -d '/home/opentts/app/voices/festival/ar' ]; then \
    cp "/home/opentts/app/voices/festival/ar/languages/language_arabic.scm" \
       "/usr/share/festival/languages/" && \
    mkdir -p "/usr/share/festival/voices/arabic" && \
    cp -r "/home/opentts/app/voices/festival/ar/voices/ara_norm_ziad_hts" "/usr/share/festival/voices/arabic/"; \
    fi

USER opentts
WORKDIR /home/opentts/app

ENTRYPOINT [".venv/bin/python3", "app.py"]

# -----------------------------------------------------------------------------
