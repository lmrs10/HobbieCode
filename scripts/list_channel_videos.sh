#!/bin/bash
# Lista los N vídeos más recientes del canal de YouTube indicado (por defecto
# HobbieCode), con id y título. No requiere cookies (usa el listado "flat" del
# canal, que no está sujeto al bloqueo agresivo de YouTube en páginas de vídeo
# individuales).
#
# Uso: ./list_channel_videos.sh [N] [CHANNEL_HANDLE]
set -e
N="${1:-20}"
CHANNEL="${2:-HobbieCode}"

yt-dlp --flat-playlist --playlist-end "$N" \
  --print "%(id)s|%(title)s" \
  "https://www.youtube.com/@${CHANNEL}/videos"
