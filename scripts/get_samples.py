#!/usr/bin/env python3
"""
Generates sample WAV files for all languages/voices.

Assumes curl is installed.
"""
import argparse
import json
import logging
import subprocess
from pathlib import Path
from urllib.parse import urlencode

# -----------------------------------------------------------------------------

_TEST_SENTENCES = {
    "ar": [
        "بالهناء والشفاء / بالهنا والشفا",
        "هل‮ ‬تحبْ‮ ‬أن‮ ‬ترقص؟",
        "حلول السنة الجديدة",
        "لغة واحدة لا تكفي",
    ],
    "bn": [
        "অনেক দিন দেখা হয়না।",
        "তোর সাথে দেখা হয়ে ভালো লাগলো।",
        "অনুগ্রহ পূর্বক পুনরায় বলুন।",
        "একটি ভাষা যথেষ্ট নয়।",
    ],
    "ca": [
        "Parli més a poc a poc, si us plau",
        "Que vagi de gust!",
        "Vols ballar amb mi?",
        "No n'hi ha prou amb una llengua",
    ],
    "cs": [
        "Těší mě, že Tě poznávám",
        "Prosím mluv pomaleji",
        "Všechno nejlepší k narozeninám!",
        "Jeden jazyk nikdy nestačí",
    ],
    "de": [
        "Können Sie bitte langsamer sprechen?",
        "Mir geht es gut, danke!",
        "Haben Sie ein vegetarisches Gericht?",
        "Ich bin allergisch.",
        "Fischers Fritze fischt frische Fische; Frische Fische fischt Fischers Fritze.",
    ],
    "en": [
        "It took me quite a long time to develop a voice, and now that I have it I'm not going to be silent.",
        "Be a voice, not an echo.",
        "I'm sorry Dave. I'm afraid I can't do that.",
        "This cake is great. It's so delicious and moist.",
        "Prior to November twenty second, nineteen sixty three.",
    ],
    "el": [
        "Καιρό έχουμε να τα πούμε!",
        "Χάρηκα για την γνωρημία.",
        "Θέλεις να χορέψεις μαζί μου;",
        "Μία γλώσσα δεν είναι ποτέ αρκετή.",
        "Το αερόστρωμνό μου είναι γεμάτο χέλια.",
    ],
    "es": [
        "Una cerveza, por favor.",
        "¿Puedes hablar más despacio?",
        "¡Siga recto! Despúes, gire a la izquierda!",
        "¿Cómo te llamas?",
        "El bebé bebe bebidas con burbujas.",
    ],
    "fi": [
        "Mikä sinun nimesi on?",
        "Tämä herrasmies maksaa kaiken",
        "Onnellista uutta vuotta",
        "Yksi kieli ei ikinä riitä",
    ],
    "fr": [
        "Pourriez-vous parler un peu moins vite?",
        "Je suis allergique.",
        "Est-ce que vous pourriez l'écrire?",
        "Avez-vous des plats végétariens?",
        "Si mon tonton tond ton tonton, ton tonton sera tondu.",
    ],
    "gu": [
        "ઘણા વખતે દેખના",
        "તમે ક્યાંના છો?આપ ક્યાંના છો?",
        "તમે મેહેરબાની કરીને થોડું ધીમે બોલશો",
        "એક ભાષા ક્યારેય પણ પુરતી નથી",
    ],
    "hi": [
        "मैं ठीक हूँ, धन्यवाद। और तुम?",
        "आप का दिन अच्छा बीते!",
        "आप की यात्रा सुखद हो",
        "एक भाषा कभी भी काफ़ी नहीं होती",
    ],
    "hu": [
        "Jó napot kívánok, a beszélőgép vagyok.",
        "Olyat mondok, hogy magam is megbánom.",
        "Bagoly mondja verébnek, hogy nagyfejű.",
        "A semminél a kevés is többet ér.",
        "Úgy él, mint Marci Hevesen.",
    ],
    "it": [
        "Da dove vieni?",
        "Parli un'altra lingua oltre l'italiano?",
        "Auguri di pronta guarigione!",
        "Una sola lingua non è mai abbastanza.",
        "Il mio aeroscafo è pieno di anguille!",
    ],
    "ja": [
        "はい、元気です。あなたは？",
        "日本語以外の言語を話しますか",
        "お誕生日おめでとうございます",
        "言語を一つは決して足りない",
        "私のホバークラフトは鰻でいっぱいです",
    ],
    "kn": [
        "ನಾ ಚಲೋ ಅದೀನಿ, ನೀವು ಹ್ಯಾಂಗದೀರ್’ರಿ?",
        "ಅಥವಾ ನೀವು ಯಾವ ಕಡೆಯವರು?",
        "ತುಂಬಾ ಸಂತೋಷ ಅಥವಾ ಖುಷಿಯಾಯ್ತು",
        "ಒಂದೇ ಭಾಷೆ ಸಾಲಲ್ಲ ಅಥವಾ ಸಾಲೋದಿಲ್ಲ",
    ],
    "ko": [
        "제 호버크래프트가 장어로 가득해요",
        "한 가지 언어는 충분하지 못 해",
        "새해 복 많이 받으시고,가정에 항상 웃음꽃 피시길 기원합니다",
        "즐거운 성탄절 보내시고 새해 복 많이 받으세요",
        "다시 한번 말씀해주시겠어요?",
    ],
    "mr": [
        "तुम्हाला भेटून आनंद झाला",
        "आयुरारोग्य लाभो",
        "वाढदिवसाच्या हार्दिक शुभेच्छा",
        "एकच भाषा कधीच पुरेशी नसते!",
    ],
    "nl": [
        "Hoe laat is het?",
        "Nog een prettige dag toegewenst.",
        "Kunt u wat langzamer praten, alstublieft?",
        "Van Harte Gefeliciteerd met je verjaardag!",
        "Moeder sneed zeven scheve sneden brood.",
    ],
    "pa": [
        "ਬੜੀ ਦੇਰ ਤੋਂ ਤੁਸੀਂ ਨਜ਼ਰ ਨਹੀਂ ਆਏ !",
        "ਤੁਹਾਨੂੰ ਮਿਲ ਕੇ ਬਹੁਤ ਖੁਸ਼ੀ ਹੋਈ",
        "ਜਨਮ ਦਿਨ ਮੁਬਾਰਕ।",
        "ਇੱਕ ਹੀ ਭਸ਼ਾ ਜਾਣ ਕੇ ਨਹੀਂ ਸਰਦਾ।",
    ],
    "ru": [
        "Вы не могли бы говорить помедленнее?",
        "Говорите ли Вы на другом языке кроме русского?",
        "С Рождеством Христовым!",
        "Одного языка никогда недостаточно",
        "Моё судно на воздушной подушке полно угрей",
    ],
    "sv": [
        "Det var länge sedan vi sågs sist!",
        "Ha en trevlig dag!",
        "Den här damen betalar för allting.",
        "Ett språk är aldrig nog.",
        "Min svävare är full med ål.",
    ],
    "sw": [
        "Nakutakia siku njema!",
        "Lugha moja haitoshi.",
        "Nimefurahi kukutana nawe.",
        "Unazungumza Kiswahili?",
        "Gari langu linaloangama limejaa na mikunga.",
    ],
    "ta": [
        "உங்கள் பெயர் என்ன?",
        "இந்த நாள் இனிய நாளாக அமையட்டும்",
        "உங்கள் உடல் விரைவாக குணம் அடையட்டும்",
        "ஒரு மொழி மட்டும் தெரிந்தால் போதாது",
    ],
    "te": [
        "నేను బాగున్నాను. మీరు ఏలా ఉన్నారు ?",
        "మిమ్మల్ని కలవడం చాలా సంతోషంగా ఉంది",
        "మీ ఆరోగ్యం త్వరలో కుదుట పడాలని కోరుకుంటున్నాను",
        "ఒక భాష సరిపోదు ",
    ],
    "tr": [
        "İyiyim sağol, sen nasılsın",
        "Tanıştıǧımıza memnun oldum",
        "Yeni yılınızı kutlar, sağlık ve başarılar dileriz",
        "Bir dil asla yeterli değildir",
    ],
    "vi": [
        "Một thứ tiếng thì không bao giờ đủ",
        "Bạn có nói tiếng Việt không?",
        "Được tiếp đãi ân cần",
        "Khoẻ, cám ơn. Bạn thì sao?",
        "Tàu cánh ngầm của tôi đầy lươn",
    ],
    "zh": ["一種語言永遠不夠", "我的氣墊船裝滿了鱔魚", "快點好啦", "你要不要跟我跳舞？", "我很高興跟你見面",],
}

_LOGGER = logging.getLogger("get_samples")

# -----------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(prog="get_samples.py")
    parser.add_argument(
        "url_base", help="Base URL of OpenTTS server (e.g. http://localhost:5500)"
    )
    parser.add_argument("output_dir", help="Path to output samples directory")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)

    url_base = args.url_base
    output_dir = Path(args.output_dir)

    if not url_base.endswith("/"):
        url_base += "/"

    voices = json.loads(
        subprocess.check_output(
            ["curl", "--silent", "-o", "-", url_base + "api/voices"],
            universal_newlines=True,
        )
    )

    # -------------------------------------------------------------------------
    # Generate keywords
    # -------------------------------------------------------------------------

    for voice_id, voice_info in voices.items():
        language = voice_info["language"]
        texts = _TEST_SENTENCES.get(language, [])
        if not texts:
            _LOGGER.warning("No sentences for %s", language)
            continue

        tts_system, voice_name = voice_id.split(":", maxsplit=1)
        if tts_system == "espeak":
            # Don't generate samples for espeak
            continue

        voice_dir = output_dir / tts_system / language / voice_name
        voice_dir.mkdir(parents=True, exist_ok=True)

        sample_key_path = voice_dir / "samples.txt"
        with open(sample_key_path, "w", encoding="utf-8") as sample_key_file:
            for sample_idx, text in enumerate(texts):
                sample_path = voice_dir / f"sample_{sample_idx+1}.wav"
                print(sample_path.stem, text, sep="|", file=sample_key_file)

                if sample_path.is_file():
                    # Skip existing files
                    continue

                subprocess.check_call(
                    [
                        "curl",
                        "--silent",
                        "-o",
                        str(sample_path),
                        url_base
                        + "api/tts?"
                        + urlencode(
                            {
                                "voice": voice_id,
                                "denoiserStrength": "0.01",
                                "text": text,
                            }
                        ),
                    ]
                )

                _LOGGER.info(sample_path)


# -----------------------------------------------------------------------------

if __name__ == "__main__":
    main()
