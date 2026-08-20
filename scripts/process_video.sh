#!/bin/bash
# Descarga un vídeo de YouTube en baja resolución + subtítulos automáticos en
# español, extrae el transcript y borra el vídeo. Usado tanto para el análisis
# manual como para la revisión diaria automática del canal.
#
# Uso: ./process_video.sh <VIDEO_ID> [WORKDIR]
#
# Requiere:
#   - yt-dlp, ffmpeg, node (>=22) instalados
#   - pip install yt-dlp-ejs   (resuelve el "n challenge" de YouTube sin necesitar --remote-components)
#   - Variable de entorno YTDLP_COOKIES_B64 con cookies de una sesión de YouTube
#     logueada, en formato Netscape cookies.txt, codificadas en base64.
#     Sin cookies válidas YouTube devuelve 429 / "Sign in to confirm you're not a bot"
#     de forma consistente.
set -e
ID="$1"
WORKROOT="${2:-work}"
DIR="$WORKROOT/$ID"
mkdir -p "$DIR"

COOKIES_FILE="$(mktemp)"
trap 'rm -f "$COOKIES_FILE"' EXIT
if [ -z "$YTDLP_COOKIES_B64" ]; then
  echo "ERROR: falta la variable de entorno YTDLP_COOKIES_B64 (cookies de YouTube en base64)." >&2
  exit 1
fi
echo "$YTDLP_COOKIES_B64" | base64 -d > "$COOKIES_FILE"

cd "$DIR"

# Descarga vídeo en baja resolución (240p, formato progresivo sin necesidad de
# resolver el "n challenge" para audio+vídeo combinados) + subtítulos
# automáticos en español, en un único paso para minimizar peticiones a YouTube.
timeout 90 yt-dlp --js-runtimes "node:/opt/node22/bin/node" --cookies "$COOKIES_FILE" \
  -f "133/134/135/bestvideo[height<=240]" \
  --write-auto-sub --sub-lang es --convert-subs srt \
  -o "video.%(ext)s" \
  "https://www.youtube.com/watch?v=$ID" > dl.log 2>&1

if [ -f video.es.srt ]; then
  python3 "$(dirname "$0")/srt_to_text.py" video.es.srt > transcript.txt
fi

ls -la
