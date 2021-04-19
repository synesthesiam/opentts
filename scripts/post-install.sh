#!/usr/bin/env bash
LANGUAGE="$1"

festival_dir='/usr/share/festival'

if [[ "${LANGUAGE}" == 'ar' ]]; then
    # Arabic
    # Install diacritizer
    # https://github.com/linuxscout/mishkal
    /app/.venv/bin/pip3 install --no-cache-dir 'mishkal~=0.4.0' 'codernitydb3'

    # Install Festival voice
    # https://github.com/linuxscout/festival-tts-arabic-voices
    festival_ar='/app/voices/festival/ar'
    cp "${festival_ar}/languages/language_arabic.scm" "${festival_dir}/languages/"
    mkdir -p "${festival_dir}/voices/arabic"
    cp -r "${festival_ar}/voices/ara_norm_ziad_hts" "${festival_dir}/voices/arabic/"
fi
