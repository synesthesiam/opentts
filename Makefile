.PHONY: check reformat venv
.SHELL := bash

DOCKER_PLATFORMS := linux/amd64
DOCKER_TAG := synesthesiam/opentts
DOCKER_BUILD := docker buildx build . -f Dockerfile2
DOCKER_RUN := docker run -it -p 5500:5500
RUN_ARGS := --debug

# all: ar bn ca cs de en es fi fr gu hi it kn mr nl pa ru sv sw ta te tr
all:
	./configure --language de,en
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):latest

run:
	$(DOCKER_RUN) $(DOCKER_TAG):latest $(RUN_ARGS)

# Arabic
ar:
	./configure --language ar
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):ar

ar-run:
	$(DOCKER_RUN) $(DOCKER_TAG):ar $(RUN_ARGS)

# Bengali
bn:
	./configure --languages bn
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):bn

bn-run:
	$(DOCKER_RUN) $(DOCKER_TAG):bn $(RUN_ARGS)

# Catalan
ca:
	./configure --language ca
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):ca

ca-run:
	$(DOCKER_RUN) $(DOCKER_TAG):ca $(RUN_ARGS)

# Czech
cs:
	./configure --language cs
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):cs

cs-run:
	$(DOCKER_RUN) $(DOCKER_TAG):cs $(RUN_ARGS)

# German
de:
	./configure --language de
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):de

de-run:
	$(DOCKER_RUN) $(DOCKER_TAG):de $(RUN_ARGS)

# Greek
el:
	./configure --language el
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):el

el-run:
	$(DOCKER_RUN) $(DOCKER_TAG):el $(RUN_ARGS)

# English
en:
	./configure --language en
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):en

en-run:
	$(DOCKER_RUN) $(DOCKER_TAG):en $(RUN_ARGS)

# Spanish
es:
	./configure --language es
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):es

es-run:
	$(DOCKER_RUN) $(DOCKER_TAG):es $(RUN_ARGS)


# Finnish
fi:
	./configure --language fi
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):fi

fi-run:
	$(DOCKER_RUN) $(DOCKER_TAG):fi $(RUN_ARGS)

# French
fr:
	./configure --language fr
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):fr

fr-run:
	$(DOCKER_RUN) $(DOCKER_TAG):fr $(RUN_ARGS)

# Gujarati
gu:
	./configure --language gu
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):gu

gu-run:
	$(DOCKER_RUN) $(DOCKER_TAG):gu $(RUN_ARGS)

# Hindi
hi:
	./configure --language hi
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):hi

hi-run:
	$(DOCKER_RUN) $(DOCKER_TAG):hi $(RUN_ARGS)

# Hungarian
hu:
	./configure --language hu
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):hu

hu-run:
	$(DOCKER_RUN) $(DOCKER_TAG):hu $(RUN_ARGS)


# Italian
it:
	./configure --language it
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):it

it-run:
	$(DOCKER_RUN) $(DOCKER_TAG):it $(RUN_ARGS)

# Kannada
kn:
	./configure --language kn
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):kn

kn-run:
	$(DOCKER_RUN) $(DOCKER_TAG):kn $(RUN_ARGS)

# Korean
ko:
	./configure --language ko
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):ko

ko-run:
	$(DOCKER_RUN) $(DOCKER_TAG):ko $(RUN_ARGS)

# Marathi
mr:
	./configure --language mr
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):mr

mr-run:
	$(DOCKER_RUN) $(DOCKER_TAG):mr $(RUN_ARGS)

# Dutch
nl:
	./configure --language nl
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):nl

nl-run:
	$(DOCKER_RUN) $(DOCKER_TAG):nl $(RUN_ARGS)

# Punjabi
pa:
	./configure --language pa
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):pa

pa-run:
	$(DOCKER_RUN) $(DOCKER_TAG):pa $(RUN_ARGS)

# Russian
ru:
	./configure --language ru
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):ru

ru-run:
	$(DOCKER_RUN) $(DOCKER_TAG):ru $(RUN_ARGS)

# Swedish
sv:
	./configure --language sv
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):sv

sv-run:
	$(DOCKER_RUN) $(DOCKER_TAG):sv $(RUN_ARGS)

# Swahili
sw:
	./configure --language sw
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):sw

sw-run:
	$(DOCKER_RUN) $(DOCKER_TAG):sw $(RUN_ARGS)

# Tamil
ta:
	./configure --language ta
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):ta

ta-run:
	$(DOCKER_RUN) $(DOCKER_TAG):ta $(RUN_ARGS)

# Telugu
te:
	./configure --language te
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):te

te-run:
	$(DOCKER_RUN) $(DOCKER_TAG):te $(RUN_ARGS)

# Turkish
tr:
	./configure --language tr
	xargs < .dockerargs $(DOCKER_BUILD) --tag $(DOCKER_TAG):tr

tr-run:
	$(DOCKER_RUN) $(DOCKER_TAG):tr $(RUN_ARGS)

check:
	scripts/check-code.sh

reformat:
	scripts/format-code.sh

venv:
	scripts/create-venv.sh
