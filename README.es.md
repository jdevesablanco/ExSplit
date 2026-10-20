# SplitExercises

**Convierte un PDF de ejercicios en otro con un ejercicio por hoja —con espacio para resolverlo— desde el clic derecho.**

[English](README.md) · macOS 13+ · Apple Silicon e Intel · licencia MIT · sin red ni cuentas

Las hojas de ejercicios suelen meter 3–6 ejercicios por página. En el iPad (Goodnotes, Notability…) o en papel quieres **un ejercicio por hoja, con el contenido original intacto (vectorial, texto seleccionable) y espacio en blanco debajo**. SplitExercises localiza dónde empieza cada ejercicio, lo recorta del PDF original y lo coloca en una hoja nueva, uniendo los que se parten entre dos páginas.

- Clic derecho en un PDF → **Acciones rápidas**, **Servicios** o **Abrir con**.
- Una mini **app de barra de menús** para cambiar el comportamiento, o sin icono: lo eliges en el primer uso.
- Todo ajustable: texto y posición de la etiqueta (6 sitios), papel, márgenes, zona de respuesta (blanco/rayas/cuadrícula/puntos), qué hacer con el original (moverlo a `Documentos/SplitExercises`, Papelera o dejarlo), nombre del resultado…
- **Deshacer** la última división con un clic.
- Funciona con PDFs escaneados (OCR de macOS, en tu Mac).
- Software libre **sin dependencias**: Swift puro sobre PDFKit / CoreGraphics / Vision (nada de PyMuPDF/AGPL ni Python).

## Instalación

**Homebrew (recomendado)**:

```bash
brew install --cask jdevesablanco/tap/splitexercises
```

Instala SplitExercises en *Aplicaciones* (y el comando `splitexercises`). Ábrela una vez para hacer la configuración inicial.

**Homebrew, compilando desde el código** (compila en tu Mac con las Command Line Tools: sin avisos de Gatekeeper):

```bash
brew install jdevesablanco/tap/splitexercises
splitexercises install        # copia SplitExercises.app a /Applications y abre la configuración inicial
```

**Instalador (.pkg)** — sin Terminal: descarga `SplitExercises-x.y.z.pkg` de [Releases](https://github.com/jdevesablanco/SplitExercises/releases), doble clic y sigue los pasos. Instala en *Aplicaciones* y abre la configuración inicial. La primera vez macOS puede avisar de que no puede verificar al desarrollador: clic derecho sobre el archivo → *Abrir*, o *Ajustes del Sistema → Privacidad y seguridad → Abrir igualmente* (no está notarizado; requiere una cuenta de Apple Developer de pago).

**DMG**: descarga `SplitExercises-x.y.z.dmg` de [Releases](https://github.com/jdevesablanco/SplitExercises/releases) y arrastra la app a *Aplicaciones*.
Está firmada *ad-hoc* y no notarizada por Apple, así que la primera vez: *Ajustes del Sistema → Privacidad y seguridad → Abrir igualmente*.
(Notarizar requiere una cuenta de Apple Developer de pago; ver [docs/NOTARIZATION.md](docs/NOTARIZATION.md).)

**Desde el código**: `git clone … && cd SplitExercises && Scripts/build-app.sh && open build/SplitExercises.app`

## Primer uso

Una bienvenida corta pregunta cómo quieres las hojas (posición de la etiqueta, zona de respuesta, qué hacer con el original), si SplitExercises debe vivir en la **barra de menús** (recomendado: cambias lo esencial o deshaces con un clic) o ser invisible, y qué entradas del clic derecho instalar.

Sin icono en la barra la app no se queda abierta. Para cambiar ajustes después: ábrela desde Spotlight/Launchpad, o **mantén ⌥ (Option)** al lanzar la acción para elegir opciones solo esa vez.

## Uso

| Dónde | Cómo |
|---|---|
| Acciones rápidas / Servicios *(recomendada)* | Clic derecho en un PDF → *Acciones rápidas* → **SplitExercises** (se instala desde la app) |
| Abrir con | Clic derecho → *Abrir con* → SplitExercises |
| Barra de menús | *Dividir PDF…*, ajustes rápidos, *Deshacer última división* |
| Claude / asistentes de IA | Pídele *«divide los ejercicios de esta carpeta»* — ver [Con Claude](#con-claude-y-otros-asistentes-de-ia) |
| Terminal | `splitexercises split archivo.pdf [opciones]` |

Mantén **⌥** en cualquiera de ellas para elegir opciones solo esa vez.

## Línea de comandos

```bash
splitexercises split ejercicios.pdf                 # con tus ajustes guardados
splitexercises split ~/Documents/Curso/Tema3        # una carpeta entera: solo toca los PDFs que son hojas de ejercicios
splitexercises split ~/Documents/Curso -r           # …incluyendo subcarpetas
splitexercises split *.pdf --original keep --suffix " (separado)" --answer grid
splitexercises generate in.pdf out.pdf --label "Problema {n}" --label-pos topRight --paper letter
splitexercises analyze ejercicios.pdf               # solo cuenta ejercicios
splitexercises analyze ~/Documents/Curso --json     # qué procesaría `split`, legible por máquinas
splitexercises undo                                 # deshace la última división
splitexercises selftest                             # prueba de humo del motor (PDF sintético)
```

En una carpeta, `split` se salta los PDFs sin ejercicios reconocibles (menos de 2), los resultados de divisiones anteriores y la carpeta de originales, y sigue si un archivo falla. `--json` imprime un informe legible por máquinas (`split`, `skipped`, `failed`).

Automatízalo: una regla de [Hazel](https://www.noodlesoft.com/) o una *Acción de carpeta* de Finder que ejecute `splitexercises split "$1"` con los PDFs nuevos.

## Con Claude (y otros asistentes de IA)

Un botón —en el primer arranque, o en *Ajustes → Finder → Con Claude*— conecta SplitExercises con Claude. Después pídele, por ejemplo: *«divide todos los ejercicios de esta carpeta»*. El comando decide qué PDFs son hojas de ejercicios y aplica **tus** ajustes, así que el asistente nunca mueve ni renombra archivos por su cuenta.

- **App de Claude (chat y Cowork)**: el botón registra una herramienta local (un servidor [MCP](https://modelcontextprotocol.io), `splitexercises mcp`) en el `claude_desktop_config.json` de Claude. Reinicia Claude una vez y *split_exercises*, *analyze_exercises* y *undo_last_split* aparecen entre sus herramientas. Se respeta tu configuración existente (se guarda una copia al lado).
- **Claude Code**: el botón instala un pequeño skill en `~/.claude/skills/splitexercises` que le enseña a ejecutar `splitexercises split`.
- **Desde Terminal**: `splitexercises connect-claude` hace lo mismo; `splitexercises connect-claude --remove` lo deshace.
- **Cualquier otro asistente con shell en tu Mac**: dile que use `splitexercises split <archivo o carpeta>` (ver `splitexercises --help`), o apunta un cliente MCP a `splitexercises mcp`. Los asistentes sin acceso a tu ordenador (chat web a secas) no pueden ejecutarlo.

Deshaz cualquier cosa con `splitexercises undo` (o *Deshacer última división* en la barra de menús).

## Cómo funciona

1. Lee el texto con posiciones (PDFKit, u OCR de Vision en escaneados) y busca la mejor serie `1.`, `1)`, `Ejercicio 1`, `Problema 1`… 1…N (o tu propia expresión regular).
2. Ignora cabeceras, pies y numeración repetidos; calcula dónde acaba el contenido con un mapa de tinta de baja resolución.
3. Recorta cada ejercicio desde su marcador hasta el siguiente, une las partes que cruzan de página y las dibuja (vectorial, con `CGContext.drawPDFPage` y recorte) en una hoja nueva con tu etiqueta y zona de respuesta.
4. Escribe primero a un temporal, lo comprueba y solo entonces mueve el original: no se pierde nada y todo se puede deshacer.

Los ajustes están en `~/Library/Application Support/SplitExercises/settings.json`.

## Límites

- Necesita ejercicios numerados. Sin numerar o a varias columnas: usa *Ajustes → Detección → patrón propio*; si no, lo dice en vez de adivinar.
- Un enunciado común antes del ejercicio 1 no se copia a cada hoja.
- Un ejercicio más largo que una hoja continúa en una segunda hoja a tamaño real (marcado *para revisar*).

## Privacidad

Todo ocurre en tu Mac. Sin telemetría ni acceso a la red.

## Licencia

MIT © 2026 Julio Devesa Blanco
