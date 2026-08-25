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
#   - Cookies de una sesión de YouTube logueada, en formato Netscape cookies.txt.
#     Sin cookies válidas YouTube devuelve 429 / "Sign in to confirm you're not a bot"
#     de forma consistente.
#     Se usan, por orden de preferencia:
#       1. /root/.secrets/cookies.txt (si existe) — fichero local fuera del repo,
#          más fácil de refrescar que la variable de entorno (que no se puede
#          modificar desde dentro de una sesión; ver README).
#       2. Variable de entorno YTDLP_COOKIES_B64 (cookies.txt codificado en base64).
set -e
ID="$1"
WORKROOT="${2:-work}"
DIR="$WORKROOT/$ID"
mkdir -p "$DIR"

LOCAL_COOKIES="/root/.secrets/cookies.txt"
if [ -f "$LOCAL_COOKIES" ]; then
  COOKIES_FILE="$LOCAL_COOKIES"
else
  COOKIES_FILE="$(mktemp)"
  trap 'rm -f "$COOKIES_FILE"' EXIT
  if [ -z "$YTDLP_COOKIES_B64" ]; then
    echo "ERROR: no hay cookies disponibles ($LOCAL_COOKIES no existe y falta YTDLP_COOKIES_B64)." >&2
    exit 1
  fi
  echo "$YTDLP_COOKIES_B64" | base64 -d > "$COOKIES_FILE"
fi

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
