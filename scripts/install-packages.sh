#!/usr/bin/env bash
JAVA='openjdk-11-jre-headless' # for MaryTTS
FESTIVAL='festival'
LARYNX_DEPS='libopenblas-base libgomp1 libatomic1'
LANGUAGE="$1"

declare -A packages
packages['ar']="${FESTIVAL}"
packages['ca']="${FESTIVAL} festvox-ca-ona-hts"
packages['cs']="${FESTIVAL} festvox-czech-dita festvox-czech-krb festvox-czech-machac festvox-czech-ph"

packages['de']="${FESTIVAL} ${JAVA} ${LARYNX_DEPS}"
packages['en']="${FESTIVAL} ${JAVA} ${LARYNX_DEPS} festvox-don festvox-en1 festvox-kallpc16k festvox-kdlpc16k festvox-rablpc16k festvox-us1 festvox-us2 festvox-us3 festvox-us-slt-hts"
packages['es']="${FESTIVAL} ${LARYNX_DEPS} festvox-ellpc11k"
packages['fi']="${FESTIVAL} festvox-suopuhe-lj festvox-suopuhe-mv"
packages['fr']="${JAVA} ${LARYNX_DEPS}"
packages['hi']="${FESTIVAL} festvox-hi-nsk"
packages['it']="${FESTIVAL} ${JAVA} ${LARYNX_DEPS} patch festvox-italp16k festvox-itapc16k"
packages['mr']="${FESTIVAL} festvox-mr-nsk"
packages['nl']="${LARYNX_DEPS}"
packages['ru']="${FESTIVAL} ${JAVA} ${LARYNX_DEPS} festvox-ru"
packages['sv']="${JAVA} ${LARYNX_DEPS}"
packages['te']="${FESTIVAL} ${JAVA} festvox-te-nsk"
packages['tr']="${JAVA}"

lang_packages="${packages["${LANGUAGE}"]}"

if [[ -n "${lang_packages}" ]]; then
    apt-get install --yes --no-install-recommends \
            ${lang_packages}
fi

if [[ "${LANGUAGE}" == 'it' ]]; then
    # Italian
    # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=943402
    # https://salsa.debian.org/tts-team/festival-it/-/blob/master/debian/patches/03_fix_return_utt_synth_types.patch

    patch -d /usr/share -p1 < /app/etc/03_fix_return_utt_synth_types.patch
fi
