.PHONY: check reformat venv
.SHELL := bash

all:
	for lang in ar bn ca cs de en  es fi fr gu hi it kn mr nl pa ru sv ta te tr; \
        do LANGUAGE=$$lang scripts/build-docker.sh; \
    done

amd64:
	NOBUILDX=1 scripts/build-docker.sh

check:
	scripts/check-code.sh

reformat:
	scripts/format-code.sh

venv:
	scripts/create-venv.sh
