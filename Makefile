.PHONY: check reformat venv
.SHELL := bash

all: ar bn ca cs de en es fi fr gu hi it kn mr nl pa ru sv ta te tr

ar:
	OPENTTS_LANG=ar scripts/build-docker.sh

bn:
	OPENTTS_LANG=bn scripts/build-docker.sh

ca:
	OPENTTS_LANG=ca scripts/build-docker.sh

cs:
	OPENTTS_LANG=cs scripts/build-docker.sh

de:
	OPENTTS_LANG=de scripts/build-docker.sh

en:
	OPENTTS_LANG=en scripts/build-docker.sh

es:
	OPENTTS_LANG=es scripts/build-docker.sh

fi:
	OPENTTS_LANG=fi scripts/build-docker.sh

fr:
	OPENTTS_LANG=fr scripts/build-docker.sh

gu:
	OPENTTS_LANG=gu scripts/build-docker.sh

hi:
	OPENTTS_LANG=hi scripts/build-docker.sh

it:
	OPENTTS_LANG=it scripts/build-docker.sh

kn:
	OPENTTS_LANG=kn scripts/build-docker.sh

mr:
	OPENTTS_LANG=mr scripts/build-docker.sh

nl:
	OPENTTS_LANG=nl scripts/build-docker.sh

pa:
	OPENTTS_LANG=pa scripts/build-docker.sh

ru:
	OPENTTS_LANG=ru scripts/build-docker.sh

sv:
	OPENTTS_LANG=sv scripts/build-docker.sh

ta:
	OPENTTS_LANG=ta scripts/build-docker.sh

te:
	OPENTTS_LANG=te scripts/build-docker.sh

tr:
	OPENTTS_LANG=tr scripts/build-docker.sh

amd64:
	NOBUILDX=1 scripts/build-docker.sh

check:
	scripts/check-code.sh

reformat:
	scripts/format-code.sh

venv:
	scripts/create-venv.sh
