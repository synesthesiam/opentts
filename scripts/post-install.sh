#!/usr/bin/env bash
set -e
LANGUAGE="$1"

PYTHON='/app/usr/local/bin/python3'
festival_dir='/usr/share/festival'

if [[ "${LANGUAGE}" == 'ar' ]]; then
    # Arabic
    # Install diacritizer
    # https://github.com/linuxscout/mishkal
    "${PYTHON}" -m pip install --no-cache-dir 'mishkal~=0.4.0' 'codernitydb3'

    # Install Festival voice
    # https://github.com/linuxscout/festival-tts-arabic-voices
    festival_ar='/app/voices/festival/ar'
    cp "${festival_ar}/languages/language_arabic.scm" "${festival_dir}/languages/"
    mkdir -p "${festival_dir}/voices/arabic"
    cp -r "${festival_ar}/voices/ara_norm_ziad_hts" "${festival_dir}/voices/arabic/"
elif [[ "${LANGUAGE}" == 'it' ]]; then
    # Italian
    # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=943402
    # https://salsa.debian.org/tts-team/festival-it/-/blob/master/debian/patches/03_fix_return_utt_synth_types.patch

    patch -d /usr/share -p1 < /app/etc/03_fix_return_utt_synth_types.patch
fi
