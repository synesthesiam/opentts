DOCKER_REGISTRY ?= docker.io
PLATFORMS ?= linux/amd64,linux/arm/v7,linux/arm64

.PHONY: check reformat venv

all:
	docker buildx build . --platform $(PLATFORMS) --tag $(DOCKER_REGISTRY)/synesthesiam/opentts --push

amd64:
	docker build . --build-arg TARGETARCH=amd64 --build-arg TARGETVARIANT='' -t synesthesiam/opentts

check:
	scripts/check-code.sh

reformat:
	scripts/format-code.sh

venv:
	scripts/create-venv.sh
