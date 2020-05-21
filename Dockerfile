FROM ubuntu:eoan
ARG TARGETARCH
ARG TARGETVARIANT

RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
        python3 python3-pip python3-venv \
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
        festvox-us-slt-hts

# Install prebuilt nanoTTS
RUN wget -O - "https://github.com/synesthesiam/prebuilt-apps/releases/download/v1.0/nanotts-20200520_${TARGETARCH}${TARGETVARIANT}.tar.gz" | \
    tar -C /usr -xzf -

# Install web server
RUN mkdir -p /app && \
    cd /app && \
    python3 -m venv . && \
    /app/bin/pip3 install --upgrade pip

COPY requirements.txt /app/
RUN /app/bin/pip3 install -r /app/requirements.txt

# Copy other files
COPY voices/ /app/voices/
COPY img/ /app/img/
COPY css/ /app/css/
COPY app.py tts.py swagger.yaml /app/
COPY templates/index.html /app/templates/

WORKDIR /app

EXPOSE 5500

ENTRYPOINT ["/app/bin/python3", "/app/app.py"]