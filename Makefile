DOCKER_REGISTRY ?= docker.io
PLATFORMS ?= linux/amd64,linux/arm/v7,linux/arm64

all:
	docker buildx build . --platform $(PLATFORMS) --tag $(DOCKER_REGISTRY)/synesthesiam/opentts --push

amd64:
	docker build . --build-arg TARGETARCH=amd64 --build-arg TARGETVARIANT='' -t synesthesiam/opentts
