.PHONY: check reformat venv
.SHELL := bash

all: ar bn ca cs de en es fi fr gu hi it kn mr nl pa ru sv ta te tr

ar:
	LANGUAGE=ar scripts/build-docker.sh

bn:
	LANGUAGE=bn scripts/build-docker.sh

ca:
	LANGUAGE=ca scripts/build-docker.sh

cs:
	LANGUAGE=cs scripts/build-docker.sh

de:
	LANGUAGE=de scripts/build-docker.sh

en:
	LANGUAGE=en scripts/build-docker.sh

es:
	LANGUAGE=es scripts/build-docker.sh

fi:
	LANGUAGE=fi scripts/build-docker.sh

fr:
	LANGUAGE=fr scripts/build-docker.sh

gu:
	LANGUAGE=gu scripts/build-docker.sh

hi:
	LANGUAGE=hi scripts/build-docker.sh

it:
	LANGUAGE=it scripts/build-docker.sh

kn:
	LANGUAGE=kn scripts/build-docker.sh

mr:
	LANGUAGE=mr scripts/build-docker.sh

nl:
	LANGUAGE=nl scripts/build-docker.sh

pa:
	LANGUAGE=pa scripts/build-docker.sh

ru:
	LANGUAGE=ru scripts/build-docker.sh

sv:
	LANGUAGE=sv scripts/build-docker.sh

ta:
	LANGUAGE=ta scripts/build-docker.sh

te:
	LANGUAGE=te scripts/build-docker.sh

tr:
	LANGUAGE=tr scripts/build-docker.sh

amd64:
	NOBUILDX=1 scripts/build-docker.sh

check:
	scripts/check-code.sh

reformat:
	scripts/format-code.sh

venv:
	scripts/create-venv.sh
