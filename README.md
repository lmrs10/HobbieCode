# HobbieCode — vigilancia de estrategias de trading algorítmico

Este repositorio es el soporte (scripts + estado) de una tarea recurrente:
vigilar el canal de YouTube [HobbieCode](https://www.youtube.com/@HobbieCode)
en busca de vídeos nuevos que expliquen **estrategias o robots de trading
algorítmico**, y generar un informe en Google Drive (con capturas de pantalla)
por cada vídeo relevante. Los vídeos que no tratan sobre estrategias/bots
(vlogs, rankings de brokers de fondeo, eventos, contenido motivacional
genérico...) se descartan y no generan informe.

**No se sube nunca el vídeo descargado a Drive** — solo se usa temporalmente
en el entorno de ejecución para extraer transcript y capturas, y se borra
después.

## Carpeta de Drive de destino

`1tQhxEzhBbux-7rjzYnjhGCQIZ8qwVN_V` (ver `drive_folder_id` en
`state/processed_videos.json`).

## Estado: `state/processed_videos.json`

Lista de vídeos ya evaluados, con su decisión (`incluido` / `excluido`) y el
motivo o el título del Google Doc generado. **Antes de procesar nada, hay que
leer este fichero para no repetir vídeos ya evaluados.** Después de cada
ejecución hay que actualizarlo (añadir los vídeos nuevos evaluados) y
commitear el cambio.

## Criterio de filtrado (amplio)

Se incluye un vídeo si trata sobre:
- una estrategia de trading concreta (reglas de entrada/salida, indicadores,
  gestión de riesgo), aunque no dé todos los detalles paso a paso;
- la construcción de un bot/robot de trading (con o sin ayuda de IA);
- el uso de IA para generar, mejorar u optimizar estrategias, indicadores o
  robots;
- metodología de validación/robustez de estrategias algorítmicas (tests de
  robustez, optimización genética, walk-forward, etc.).

Se excluye si el vídeo trata de:
- contenido puramente motivacional/estadístico sin estrategia concreta;
- infraestructura para *operar* bots ya existentes (VPS, ejecución desde el
  móvil...) sin explicar la estrategia ni construir el bot;
- rankings o comparativas de empresas de fondeo (prop firms) sin estrategia;
- paneles de noticias/sentimiento de mercado que no generan ni ejecutan una
  estrategia;
- eventos, anuncios, vlogs personales.

Ante la duda, mirar el título, la descripción y — sobre todo — el transcript
antes de decidir.

## Pipeline técnico

### 1. Cookies de YouTube (imprescindible)

YouTube bloquea agresivamente (HTTP 429 / "Sign in to confirm you're not a
bot") las peticiones a páginas de vídeo individuales sin cookies de sesión
válidas. Hace falta la variable de entorno `YTDLP_COOKIES_B64` con un
`cookies.txt` (formato Netscape) de una sesión de YouTube logueada,
codificado en base64:

```bash
base64 -w0 cookies.txt
```

Esta variable se configura en los ajustes del entorno de Claude Code (no en
este repo, por seguridad). **Las cookies caducan/rotan** — si `scripts/process_video.sh`
empieza a fallar con 429 o "cookies no longer valid", hay que pedir al
usuario un `cookies.txt` fresco y volver a codificar la variable de entorno.

### 2. Dependencias del entorno

- `yt-dlp`, `ffmpeg`, `node` (≥22) — para el "n challenge" de YouTube hace
  falta además `pip install yt-dlp-ejs` (evita tener que descargar el script
  solucionador vía `--remote-components`, que además falla por el certificado
  del proxy de este entorno).
- `node scripts/docxgen/build_report.js` usa el paquete npm `docx` — si no
  está instalado: `cd scripts/docxgen && npm install docx`.

### 3. Listar vídeos del canal

```bash
scripts/list_channel_videos.sh 20   # 20 vídeos más recientes, id|título
```

No necesita cookies (usa el listado "flat" del canal).

### 4. Descargar + transcribir + capturar un vídeo

```bash
scripts/process_video.sh <VIDEO_ID> [directorio_de_trabajo]
```

Descarga el vídeo en 240p (con audio, sin necesitar resolver el "n
challenge" de formatos DASH), los subtítulos automáticos en español, y
genera `transcript.txt` (limpio de los cues duplicados típicos de los
subtítulos "rolling" de YouTube). El vídeo (`video.mp4`) hay que borrarlo
después de extraer los frames — nunca debe llegar a Drive.

```bash
scripts/extract_frames.sh <ruta_video.mp4> <directorio_salida>
```

Extrae 7 frames en JPEG a intervalos de duración (8%, 22%, 36%, 50%, 64%,
78%, 90%). Conviene revisar visualmente 2-3 frames por vídeo y elegir los que
muestren contenido útil (gráficos, código, paneles de configuración) en vez
de solo la cara del presentador.

### 5. Redactar el resumen del informe

Este paso requiere criterio humano/LLM: leer `transcript.txt` (y la
descripción del vídeo) y redactar en español un resumen estructurado de la
estrategia — instrumento, reglas de entrada/salida, gestión de riesgo,
resultados si se mencionan, herramientas usadas (StrategyQuant, Claude Code,
MetaTrader...). No hay script para esto: lo hace el agente/persona que
ejecuta la revisión.

### 6. Generar el documento

```bash
node scripts/docxgen/build_report.js spec.json salida.docx
```

`spec.json` sigue este esquema (ver ejemplos ya generados, o pedir al agente
que los reconstruya):

```json
{
  "title": "Título del vídeo",
  "channel": "Hobbiecode",
  "publishedDisplay": "12 de julio de 2026",
  "durationDisplay": "14 min 55 s",
  "url": "https://www.youtube.com/watch?v=...",
  "sections": [
    { "heading": "Resumen", "content": ["texto...", {"bullets": ["punto 1", "punto 2"]}] }
  ],
  "screenshots": [
    { "file": "/ruta/a/frame.jpg", "caption": "Qué se ve en la captura" }
  ]
}
```

### 7. Subir a Drive como Google Doc

Con las herramientas MCP de Google Drive: `mcp__Google_Drive__create_file`,
pasando el `.docx` como `base64Content` con
`contentMimeType: application/vnd.openxmlformats-officedocument.wordprocessingml.document`,
`parentId` la carpeta de destino, y **sin** `disableConversionToGoogleType`
(así Drive lo convierte automáticamente a un Google Doc nativo con las
imágenes incrustadas). Título recomendado: `AAAA-MM-DD - Título del vídeo`.

Para no inflar el contexto de la conversación con el base64 (puede pesar
cientos de miles de tokens en texto), es preferible delegar la subida a un
subagente en vez de leer el fichero con la herramienta `Read` del hilo
principal.

### 8. Actualizar el estado y commitear

Añadir la entrada correspondiente en `state/processed_videos.json` (decisión,
motivo o título del doc) y hacer commit + push.

## Automatización diaria

Hay configurada una Routine (trigger programado) que ejecuta este flujo una
vez al día. Ver la configuración del trigger para el prompt exacto que
recibe cada ejecución.
