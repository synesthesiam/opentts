.PHONY: check reformat venv
.SHELL := bash

all:
	scripts/build-docker.sh

amd64:
	NOBUILDX=1 scripts/build-docker.sh

check:
	scripts/check-code.sh

reformat:
	scripts/format-code.sh

venv:
	scripts/create-venv.sh
