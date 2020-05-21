amd64:
	docker build . --build-arg TARGETARCH=amd64 --build-arg TARGETVARIANT='' -t synesthesiam/opentts
