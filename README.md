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
válidas. `scripts/process_video.sh` necesita un `cookies.txt` (formato
Netscape) de una sesión de YouTube logueada, y lo busca por este orden:

1. **`/root/.secrets/cookies.txt`** (recomendado) — fichero local en texto
   plano, fuera del repo (nunca se commitea). Es la forma preferida de
   refrescar las cookies porque se puede escribir directamente desde una
   sesión (`Write`/`Bash`), sin tocar ajustes externos. Cuando el usuario
   pegue un `cookies.txt` fresco en el chat, guárdalo ahí con permisos `600`.
2. **Variable de entorno `YTDLP_COOKIES_B64`** (el mismo `cookies.txt`
   codificado en base64: `base64 -w0 cookies.txt`) — solo como fallback si no
   existe el fichero local. Esta variable se configura en los ajustes del
   entorno de Claude Code (no en este repo); **no se puede modificar desde
   dentro de una sesión** (escribir en `~/.bashrc` u otros ficheros de shell
   está bloqueado por el clasificador de seguridad), así que si solo cuentas
   con esta vía, un cambio de cookies solo dura para la sesión actual.

**Las cookies caducan/rotan** — si el pipeline empieza a fallar con 429 o
"cookies no longer valid", pide al usuario un `cookies.txt` fresco y
guárdalo en `/root/.secrets/cookies.txt` (sobrescribiendo el anterior) para
que las próximas ejecuciones de la Routine también lo usen.

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

Este paso requiere criterio humano/LLM: leer el `transcript.txt` **completo**
(no solo un resumen o los primeros minutos) y la descripción del vídeo, y
redactar en español un informe estructurado.

**Estándar de calidad (obligatorio, no opcional):** el objetivo de estos
informes es que alguien pueda *implementar* la estrategia a partir del
documento, sin volver a ver el vídeo. Eso exige:

- Una sección explícita **"Reglas de la estrategia"** (o título equivalente)
  con los parámetros concretos mencionados en el vídeo, en formato
  `Parámetro: Valor` — periodos de indicadores exactos (p. ej. "EMA 200", no
  "una media móvil larga"), condiciones de entrada y salida, stop
  loss/take profit (valores o ratios exactos), tamaño de posición o riesgo
  por operación, activo y temporalidad si se especifican, y resultados de
  backtest si se mencionan (win rate, nº de operaciones, periodo probado).
- **Nunca rellenar con vaguedades** cuando el transcript no da un dato
  concreto — mejor decir explícitamente "la fuente no especifica X" que
  inventar o difuminar el dato.
- Si el vídeo **no contiene ninguna regla de estrategia operable** (vídeos de
  opinión, gestión de cuentas de fondeo, EAs de gestión de riesgo sin lógica
  de entrada/salida, etc.), el informe debe decirlo con una sección de
  **"Aviso"** al principio explicando claramente qué es y qué no es el vídeo,
  en vez de disfrazar contenido vago como si fueran reglas. Si además el
  vídeo no aporta prácticamente nada aprovechable, reconsiderar si debería
  estar `excluido` según el criterio de filtrado de arriba, aunque roce el
  criterio amplio de inclusión.
- Incluir siempre: instrumento/activo, temporalidad, herramientas usadas
  (StrategyQuant, Claude Code, MetaTrader, Pine Script...), y cualquier
  resultado numérico de validación que se mencione, con sus cifras exactas.

No hay script para esto: lo hace el agente/persona que ejecuta la revisión,
y debe releer el transcript entero antes de dar el informe por terminado —
no basta con una pasada rápida u orientada solo a extraer un resumen.

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

### 7. Subir a Drive

Con las herramientas MCP de Google Drive: `mcp__Google_Drive__create_file`,
pasando el `.docx` como `base64Content` con
`contentMimeType: application/vnd.openxmlformats-officedocument.wordprocessingml.document`,
`parentId` la carpeta de destino, y `disableConversionToGoogleType: true`.
Título recomendado: `AAAA-MM-DD - Título del vídeo`.

**Nota:** se intentó dejar que Drive convirtiera automáticamente el `.docx`
a un Google Doc nativo (parámetro `disableConversionToGoogleType: false` u
omitido) pero esta carpeta/cuenta devuelve `Invalid conversion requested` —
la conversión automática no funciona aquí. Los informes quedan como
documento Word nativo en Drive, lo cual sigue siendo perfectamente
funcional (se abren directamente con Google Docs desde el navegador; el
usuario puede convertirlos a Google Doc manualmente con "Abrir con >
Google Docs" si lo prefiere). No merece la pena reintentar la conversión
automática en cada ejecución.

Para no inflar el contexto de la conversación con el base64 (puede pesar
cientos de miles de tokens en texto), es preferible delegar la subida a un
subagente en vez de leer el fichero con la herramienta `Read` del hilo
principal. Dale al subagente los parámetros exactos de arriba directamente
(no le pidas que "explore" la API) para que no malgaste tiempo probando
variantes de conversión que ya sabemos que fallan.

### 8. Actualizar el estado y commitear

Añadir la entrada correspondiente en `state/processed_videos.json` (decisión,
motivo o título del doc) y hacer commit + push.

## Automatización diaria

Hay configurada una Routine (trigger programado) que ejecuta este flujo una
vez al día. Ver la configuración del trigger para el prompt exacto que
recibe cada ejecución.
