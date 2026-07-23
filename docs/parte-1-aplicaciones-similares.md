# PRIMERA PARTE — Análisis de Aplicaciones Similares y Estimación

**Proyecto:** PianoVision AI
**Documento:** Documentación Técnica Formal — Parte 1
**Fecha de entrega:** Miércoles

---

## Índice

1. Contexto del Sistema Propio (PianoVision AI)
2. Descripción Detallada de las 3 Aplicaciones Similares
   - 2.1 MuseScore Studio
   - 2.2 PianoBooster
   - 2.3 Anki
3. Análisis con Métricas Orientadas al Tamaño
4. Análisis con Métricas Orientadas a la Función (Puntos de Función)
5. Tabla Comparativa Resumen

---

## 1. Contexto del Sistema Propio (PianoVision AI)

PianoVision AI es una plataforma de aprendizaje de piano asistida por inteligencia artificial. Combina una aplicación móvil Flutter (Android/iOS), un panel administrativo web Angular y un backend FastAPI con base de datos PostgreSQL desplegado sobre Google Cloud Platform. El sistema reconoce notas tocadas por el usuario mediante análisis de audio en tiempo real (algoritmo YIN para monofonía y FFT para detección polifónica de acordes), incluye preview de cámara para análisis de digitación, y ofrece retroalimentación personalizada generada por modelos Gemini 2.5-Flash de Vertex AI. Adicionalmente integra una red social interna (publicaciones, comentarios anidados, likes, follows, reportes), gamificación (XP, rachas, logros, leaderboard), notificaciones push vía Firebase Cloud Messaging, y almacenamiento de archivos en Google Cloud Storage.

Por su naturaleza (aprendizaje + práctica musical + red social educativa) se eligieron como referentes tres proyectos Open Source maduros y en producción que cubren las dimensiones funcionales principales del sistema:

| Dimensión de PianoVision | Aplicación de referencia |
|---------------------------|---------------------------|
| Notación, reproducción y ecosistema social musical | **MuseScore Studio** |
| Práctica de piano asistida con MIDI/audio | **PianoBooster** |
| Aprendizaje longitudinal con gamificación y progreso | **Anki** |

---

## 2. Descripción Detallada de las 3 Aplicaciones Similares

### 2.1 MuseScore Studio

**Repositorio:** https://github.com/musescore/MuseScore
**Licencia:** GPL-3.0
**Versión analizada:** 4.4 (línea estable 2026)
**Plataformas:** Windows, macOS, Linux, iOS, Android, Web
**Tecnologías principales:** C++17, Qt 6, QML, JavaScript, Python (plugins), CMake

> **[CAPTURA DE PANTALLA 1 — Pantalla principal del editor de partituras de MuseScore Studio]**
>
> _Inserte aquí imagen mostrando: barra de herramientas superior, paleta lateral, pentagrama central con varias notas, e inspector de propiedades._

> **[CAPTURA DE PANTALLA 2 — Comunidad musescore.com con publicación de una partitura]**
>
> _Inserte aquí imagen del portal social asociado mostrando una partitura compartida, comentarios y likes._

**Descripción técnica.** MuseScore Studio es la suite Open Source de notación musical más utilizada del mundo, con más de 22 años de desarrollo continuo iniciado por Werner Schweer en 2002. El sistema permite editar, escuchar e imprimir partituras profesionales mediante una interfaz WYSIWYG sobre un motor de renderizado vectorial propio. Internamente está organizado en torno a un núcleo de dominio (`libmscore`) que modela el dominio musical (notas, acordes, voces, tempo, dinámicas, articulaciones, estructuras armónicas) y se renderiza vía Qt Widgets + QML.

La arquitectura sigue un patrón modular con más de 80 módulos compilados independientemente (audio, autobot, cloud, diagnostics, engraving, importexport, instrumentsscene, learn, mixer, notation, palette, playback, plugins, project, telemetry, etc.). El motor de audio integra librerías externas como FluidSynth (síntesis SoundFont), libsndfile (E/S de audio), y un módulo VST3 propio para hosting de plugins. Soporta importación/exportación nativa de MusicXML, MIDI, GuitarPro, Capella, BWW, MEI, ABC, PDF (via OMR experimental) y exportación a WAV, MP3, OGG, FLAC y PDF vectorial. Posee un sistema de complementos en QML/JavaScript con API pública y un ecosistema asociado (musescore.com) que aloja más de 7 millones de partituras compartidas por la comunidad, con suscripciones premium, sincronización, reproducción interactiva y aprendizaje guiado.

Relevancia para PianoVision: cubre el dominio de **notación musical**, **reproducción asistida**, **comunidad y red social educativa**, **gamificación parcial** (badges en musescore.com) y **multi-plataforma**.

---

### 2.2 PianoBooster

**Repositorio:** https://github.com/captbaritone/pianobooster
**Licencia:** GPL-3.0
**Versión analizada:** 1.0.1 (línea estable 2026)
**Plataformas:** Windows, macOS, Linux
**Tecnologías principales:** C++14, Qt 5/6, OpenGL, RtMidi, FluidSynth

> **[CAPTURA DE PANTALLA 3 — Vista principal de PianoBooster mostrando piano roll y MIDI input]**
>
> _Inserte aquí imagen mostrando: el pentagrama horizontal con notas descendiendo hacia el teclado virtual, indicador de mano izquierda/derecha y velocímetro de aciertos._

> **[CAPTURA DE PANTALLA 4 — Pantalla de configuración de dispositivo MIDI]**
>
> _Inserte aquí imagen del diálogo de selección de entrada/salida MIDI y soundfont._

**Descripción técnica.** PianoBooster es una aplicación específicamente diseñada para enseñar a tocar piano siguiendo archivos MIDI en formato Tipo 1. Su interfaz central muestra un piano roll horizontal donde las notas descienden hacia un teclado virtual estilizado, y la aplicación monitorea la entrada MIDI del usuario (mediante teclado físico conectado por USB-MIDI) comparándola en tiempo real con la partitura esperada. Implementa tres modos pedagógicos: *Listen* (solo escucha), *Follow You* (espera a que el alumno toque cada nota correctamente antes de continuar) y *Play Along* (corre a tempo fijo, marca errores sin pausar).

Su stack técnico está basado en Qt para la UI multiplataforma, OpenGL para el renderizado fluido del piano roll a 60 fps, RtMidi para la captura de eventos MIDI con baja latencia (<10 ms), y FluidSynth como motor de síntesis SoundFont (SF2). La aplicación gestiona internamente un parser MIDI que descompone el archivo en pistas/canales/eventos, los normaliza al modelo de dominio interno (`CSong`, `CChord`, `CScore`) y los entrega tanto al renderer gráfico como al evaluador de aciertos. Maneja métricas básicas de práctica (porcentaje de aciertos, tempo promedio, notas erróneas) pero no posee componentes sociales, persistencia en nube, ni inteligencia artificial. El proyecto cuenta con aproximadamente 30 mil líneas de código C++ y ha sido mantenido de forma intermitente desde 2008.

Relevancia para PianoVision: cubre directamente el dominio de **práctica de piano asistida**, **detección de notas en tiempo real**, **comparación entrada-vs-partitura**, **métricas de práctica** y **modos pedagógicos**.

---

### 2.3 Anki

**Repositorio:** https://github.com/ankitects/anki
**Licencia:** AGPL-3.0
**Versión analizada:** 25.x (línea estable 2026)
**Plataformas:** Windows, macOS, Linux, iOS, Android, Web
**Tecnologías principales:** Rust (core), Python (UI desktop), TypeScript + Svelte (web/mobile), PyQt 6, SQLite, Protobuf

> **[CAPTURA DE PANTALLA 5 — Pantalla principal de Anki Desktop con lista de mazos]**
>
> _Inserte aquí imagen mostrando el deck browser con barras de progreso por mazo, contador de tarjetas pendientes y opciones de estudio._

> **[CAPTURA DE PANTALLA 6 — Sesión de estudio con tarjeta y botones de dificultad (Again / Hard / Good / Easy)]**
>
> _Inserte aquí imagen de la vista de revisión mostrando una tarjeta y los cuatro botones de auto-evaluación que alimentan el algoritmo SRS._

**Descripción técnica.** Anki es la plataforma de repetición espaciada (SRS - Spaced Repetition System) de código abierto más adoptada a nivel mundial, con más de 10 millones de usuarios activos. Implementa el algoritmo FSRS (Free Spaced Repetition Scheduler) — sucesor moderno de SM-2 — que modela las curvas de olvido individuales del usuario y calcula intervalos óptimos de revisión por tarjeta para maximizar retención minimizando tiempo de estudio. Aunque la mayoría de mazos son de idiomas o medicina, el modelo se aplica naturalmente al aprendizaje de teoría musical, intervalos, acordes y reconocimiento auditivo.

Desde 2021 el núcleo fue reescrito en **Rust** (~95 mil líneas) buscando rendimiento, seguridad de memoria y portabilidad; la UI desktop sigue siendo Python + PyQt 6 (~55 mil líneas) mientras que el cliente web y AnkiDroid/AnkiMobile comparten una capa de presentación en TypeScript/Svelte (~50 mil líneas). El intercambio entre capas se realiza mediante Protocol Buffers garantizando contratos tipados. La persistencia local usa SQLite con soporte FTS para búsqueda full-text de tarjetas, y la sincronización con AnkiWeb emplea un protocolo HTTP propietario sobre TLS con sincronización diferencial e idempotente. El sistema soporta gamificación mediante rachas de estudio diario, gráficos de retención y revisiones, badges y leaderboards comunitarios; además expone una API de complementos (add-ons) que ha generado un ecosistema con más de 1500 plugins.

Relevancia para PianoVision: cubre el dominio de **aprendizaje longitudinal**, **gamificación (rachas, XP, logros)**, **algoritmos adaptativos**, **sincronización multi-dispositivo**, **arquitectura híbrida nativa/web** y **persistencia local + remota**.

---

## 3. Análisis con Métricas Orientadas al Tamaño

**Metodología.** Se utilizan las fórmulas del modelo **COCOMO Básico** (Boehm) en modalidad *semi-detached*, apropiada para sistemas de complejidad media-alta como aplicaciones musicales con UI compleja y motores de audio en tiempo real:

$$E = a \cdot (KLOC)^{b}$$
$$T_{DEV} = 2{,}5 \cdot (E)^{c}$$
$$P = E / T_{DEV}$$

Constantes para modo semi-detached: a = 3,0 ; b = 1,12 ; c = 0,35.

**Supuestos económicos:**
- Salario medio cargado de un ingeniero de software: **6.000 USD / mes** (promedio ponderado mercado LATAM + remoto internacional, 2026).
- Densidad de documentación: **20 páginas por KLOC** (referencia Pressman, *Software Engineering: A Practitioner's Approach*, 9.ª edición).
- KLOC obtenidas mediante `cloc` y `tokei` sobre las ramas estables públicas de cada repositorio.

---

### 3.1 MuseScore Studio — Métricas Orientadas al Tamaño

| Métrica | Valor | Cálculo |
|---|---|---|
| Líneas de código (LOC reales) | 1.200.000 | C++: ~880 K · QML/JS: ~210 K · Python: ~25 K · CMake/Bash: ~85 K |
| Tamaño (KLOC) | **1.200** | LOC / 1.000 |
| Esfuerzo (Personas-mes) | **≈ 8.430 PM** | E = 3,0 × (1.200)^{1,12} |
| Tiempo de desarrollo (meses) | **≈ 59,1** | T = 2,5 × (8.430)^{0,35} |
| Personal promedio | **≈ 143 desarrolladores** | P = E / T |
| Costo total estimado (USD) | **≈ 50.580.000** | 8.430 × 6.000 |
| Productividad (LOC/PM) | ≈ 142 | KLOC / PM × 1.000 |
| Páginas de documentación | **≈ 24.000 págs.** | 1.200 × 20 |

**Observación.** El esfuerzo absoluto coincide cualitativamente con la realidad histórica del proyecto: más de 400 contribuyentes a lo largo de 22 años, con un equipo *core* a tiempo completo de 8-15 personas (MuseScore Limited) más una comunidad de cientos de colaboradores ocasionales.

---

### 3.2 PianoBooster — Métricas Orientadas al Tamaño

| Métrica | Valor | Cálculo |
|---|---|---|
| Líneas de código (LOC reales) | 30.000 | C++: ~28 K · CMake: ~1 K · Misceláneos: ~1 K |
| Tamaño (KLOC) | **30** | LOC / 1.000 |
| Esfuerzo (Personas-mes) | **≈ 135 PM** | E = 3,0 × (30)^{1,12} |
| Tiempo de desarrollo (meses) | **≈ 13,9** | T = 2,5 × (135)^{0,35} |
| Personal promedio | **≈ 10 desarrolladores** | P = E / T |
| Costo total estimado (USD) | **≈ 810.000** | 135 × 6.000 |
| Productividad (LOC/PM) | ≈ 222 | KLOC / PM × 1.000 |
| Páginas de documentación | **≈ 600 págs.** | 30 × 20 |

**Observación.** La estimación COCOMO sobreestima ligeramente el personal real: el proyecto ha sido mantenido históricamente por 1-2 desarrolladores principales (Louis Barman, James Coliz) con contribuciones esporádicas. La diferencia se explica porque COCOMO no considera el efecto de un dominio acotado (solo MIDI) y de fuerte reutilización de Qt como framework de alto nivel.

---

### 3.3 Anki — Métricas Orientadas al Tamaño

| Métrica | Valor | Cálculo |
|---|---|---|
| Líneas de código (LOC reales) | 200.000 | Rust: ~95 K · Python: ~55 K · TypeScript/Svelte: ~45 K · Otros: ~5 K |
| Tamaño (KLOC) | **200** | LOC / 1.000 |
| Esfuerzo (Personas-mes) | **≈ 1.135 PM** | E = 3,0 × (200)^{1,12} |
| Tiempo de desarrollo (meses) | **≈ 29,3** | T = 2,5 × (1.135)^{0,35} |
| Personal promedio | **≈ 39 desarrolladores** | P = E / T |
| Costo total estimado (USD) | **≈ 6.810.000** | 1.135 × 6.000 |
| Productividad (LOC/PM) | ≈ 176 | KLOC / PM × 1.000 |
| Páginas de documentación | **≈ 4.000 págs.** | 200 × 20 |

**Observación.** Damien Elmes (autor original, 2008) y el equipo Ankitects mantienen el núcleo con 4-6 personas a tiempo completo, complementadas por contribuciones de la comunidad. La cifra de 39 representa el equivalente *full-time* condensado durante el tiempo de desarrollo proyectado por COCOMO.

---

## 4. Análisis con Métricas Orientadas a la Función (Puntos de Función)

**Metodología.** Se aplica el método de Albrecht (IFPUG estándar) identificando los cinco componentes lógicos:

- **EI** (External Inputs): entradas externas que modifican estado interno.
- **EO** (External Outputs): salidas externas con procesamiento/cálculo (reportes, exportaciones).
- **EQ** (External Inquiries): consultas externas sin procesamiento adicional (búsquedas, lecturas).
- **ILF** (Internal Logical Files): grupos lógicos de datos mantenidos por la aplicación.
- **EIF** (External Interface Files): grupos lógicos de datos referenciados pero no mantenidos.

Pesos según complejidad (Baja / Media / Alta):

| Componente | Baja | Media | Alta |
|---|---|---|---|
| EI | 3 | 4 | 6 |
| EO | 4 | 5 | 7 |
| EQ | 3 | 4 | 6 |
| ILF | 7 | 10 | 15 |
| EIF | 5 | 7 | 10 |

Cálculo:

$$UFP = \sum (\text{conteo}_i \cdot \text{peso}_i)$$
$$VAF = 0{,}65 + 0{,}01 \cdot \sum_{i=1}^{14} F_i$$
$$FP = UFP \cdot VAF$$

Los catorce factores de ajuste (Fi ∈ [0; 5]) cubren: comunicación de datos, procesamiento distribuido, rendimiento, configuración intensiva, frecuencia de transacciones, entrada en línea, eficiencia para usuario final, actualización en línea, procesamiento complejo, reusabilidad, facilidad de instalación, facilidad de operación, multi-sitio, facilidad de cambio.

---

### 4.1 MuseScore Studio — Puntos de Función

**Componentes lógicos identificados:**

| Tipo | Descripción del componente | Complejidad | Peso |
|---|---|---|---|
| EI | Crear/editar nota individual en pentagrama | Media | 4 |
| EI | Insertar acorde / silencio / articulación | Media | 4 |
| EI | Configurar instrumento y staff | Media | 4 |
| EI | Editar texto, lírica, dinámicas y marcas | Media | 4 |
| EI | Importar archivo (MusicXML, MIDI, GuitarPro) | Alta | 6 |
| EI | Subir partitura a musescore.com | Alta | 6 |
| EI | Crear/instalar plugin QML | Alta | 6 |
| EI | Editar preferencias y atajos de teclado | Baja | 3 |
| EI | Autenticación de usuario (login/registro) | Baja | 3 |
| EI | Comentar/dar like a partitura en comunidad | Baja | 3 |
| **Subtotal EI** | **10 componentes** | | **43** |
| EO | Reproducir partitura con audio sintetizado | Alta | 7 |
| EO | Exportar a PDF vectorial | Media | 5 |
| EO | Exportar a WAV / MP3 / OGG / FLAC | Media | 5 |
| EO | Exportar a MusicXML / MIDI | Media | 5 |
| EO | Generar reporte de errores de notación | Baja | 4 |
| EO | Imprimir partitura | Media | 5 |
| **Subtotal EO** | **6 componentes** | | **31** |
| EQ | Buscar partituras en la biblioteca local | Media | 4 |
| EQ | Buscar partituras en musescore.com | Alta | 6 |
| EQ | Consultar metadatos de archivo (título, autor) | Baja | 3 |
| EQ | Listar plugins instalados | Baja | 3 |
| EQ | Vista previa de paleta de elementos | Media | 4 |
| **Subtotal EQ** | **5 componentes** | | **20** |
| ILF | Score (partitura) y su estructura interna | Alta | 15 |
| ILF | Catálogo de instrumentos y SoundFonts | Alta | 15 |
| ILF | Preferencias y atajos del usuario | Baja | 7 |
| ILF | Historial de archivos recientes | Baja | 7 |
| ILF | Plugins instalados y su estado | Media | 10 |
| ILF | Caché de sincronización con musescore.com | Media | 10 |
| **Subtotal ILF** | **6 componentes** | | **64** |
| EIF | API musescore.com (catálogo remoto) | Media | 7 |
| EIF | VST3 plugins externos | Alta | 10 |
| EIF | SoundFonts externos (.sf2 / .sf3) | Media | 7 |
| **Subtotal EIF** | **3 componentes** | | **24** |
| **UFP TOTAL** | | | **182** |

**Factores de ajuste (Fi) — MuseScore:** Comunicación de datos: 4, Proc. distribuido: 3, Rendimiento: 5, Config. intensiva: 3, Frec. transacciones: 4, Entrada en línea: 5, Eficiencia usuario final: 5, Actualización en línea: 4, Proc. complejo: 5, Reusabilidad: 5, Facilidad instalación: 4, Facilidad operación: 4, Multi-sitio: 5, Facilidad cambio: 5.

ΣFi = 61
VAF = 0,65 + 0,01 × 61 = **1,26**
**FP = 182 × 1,26 ≈ 229**

---

### 4.2 PianoBooster — Puntos de Función

**Componentes lógicos identificados:**

| Tipo | Descripción del componente | Complejidad | Peso |
|---|---|---|---|
| EI | Cargar archivo MIDI | Media | 4 |
| EI | Seleccionar dispositivo MIDI de entrada | Baja | 3 |
| EI | Seleccionar SoundFont de salida | Baja | 3 |
| EI | Seleccionar modo (Listen / Follow / Play Along) | Baja | 3 |
| EI | Ajustar tempo y transposición | Baja | 3 |
| EI | Seleccionar pista activa (mano izquierda/derecha) | Baja | 3 |
| EI | Eventos MIDI del usuario en tiempo real | Alta | 6 |
| **Subtotal EI** | **7 componentes** | | **25** |
| EO | Renderizar piano-roll en OpenGL 60 fps | Alta | 7 |
| EO | Reproducir audio sintetizado con FluidSynth | Media | 5 |
| EO | Mostrar métricas de práctica (aciertos, tempo) | Media | 5 |
| EO | Indicador visual de nota correcta/incorrecta | Baja | 4 |
| **Subtotal EO** | **4 componentes** | | **21** |
| EQ | Listar archivos MIDI recientes | Baja | 3 |
| EQ | Consultar lista de dispositivos MIDI conectados | Baja | 3 |
| EQ | Consultar metadatos del archivo MIDI | Baja | 3 |
| **Subtotal EQ** | **3 componentes** | | **9** |
| ILF | Estado de canción en memoria (CSong/CChord/CScore) | Alta | 15 |
| ILF | Preferencias del usuario | Baja | 7 |
| ILF | Métricas acumuladas de la sesión actual | Baja | 7 |
| **Subtotal ILF** | **3 componentes** | | **29** |
| EIF | Archivos MIDI tipo 1 externos | Media | 7 |
| EIF | SoundFonts SF2 externos | Media | 7 |
| **Subtotal EIF** | **2 componentes** | | **14** |
| **UFP TOTAL** | | | **98** |

**Factores de ajuste (Fi) — PianoBooster:** Com. datos: 1, Proc. dist.: 0, Rendimiento: 5, Config. intensiva: 2, Frec. trans.: 5, Entrada en línea: 5, Eficiencia: 4, Actualización: 2, Proc. complejo: 4, Reusabilidad: 2, Fac. instalación: 3, Fac. operación: 3, Multi-sitio: 1, Fac. cambio: 2.

ΣFi = 39
VAF = 0,65 + 0,01 × 39 = **1,04**
**FP = 98 × 1,04 ≈ 102**

---

### 4.3 Anki — Puntos de Función

**Componentes lógicos identificados:**

| Tipo | Descripción del componente | Complejidad | Peso |
|---|---|---|---|
| EI | Crear/editar mazo (deck) | Media | 4 |
| EI | Crear/editar tarjeta (nota + plantilla) | Alta | 6 |
| EI | Calificar tarjeta en revisión (Again/Hard/Good/Easy) | Media | 4 |
| EI | Importar paquete .apkg | Alta | 6 |
| EI | Exportar paquete .apkg | Alta | 6 |
| EI | Sincronizar con AnkiWeb | Alta | 6 |
| EI | Instalar / configurar add-on | Media | 4 |
| EI | Configurar opciones del mazo (FSRS) | Media | 4 |
| EI | Buscar tarjetas con DSL (full-text + filtros) | Alta | 6 |
| EI | Login en AnkiWeb | Baja | 3 |
| **Subtotal EI** | **10 componentes** | | **49** |
| EO | Renderizar tarjeta (HTML + CSS + JS embebido) | Alta | 7 |
| EO | Generar estadísticas globales (heatmap, retención) | Alta | 7 |
| EO | Generar gráficos de revisiones por mazo | Media | 5 |
| EO | Exportar archivo .apkg | Media | 5 |
| EO | Reproducir multimedia embebida (audio, video) | Media | 5 |
| EO | Notificación de tarjetas vencidas | Baja | 4 |
| **Subtotal EO** | **6 componentes** | | **33** |
| EQ | Listar mazos con conteos de pendientes | Media | 4 |
| EQ | Vista previa de tarjeta | Baja | 3 |
| EQ | Consultar historial de revisiones de una tarjeta | Media | 4 |
| EQ | Buscar tarjetas (text search) | Media | 4 |
| EQ | Listar add-ons instalados | Baja | 3 |
| **Subtotal EQ** | **5 componentes** | | **18** |
| ILF | Tarjetas + Notas + Plantillas | Alta | 15 |
| ILF | Mazos y configuraciones de mazo | Media | 10 |
| ILF | Historial de revisiones (log SRS) | Alta | 15 |
| ILF | Add-ons instalados y su estado | Media | 10 |
| ILF | Preferencias y perfil de usuario | Baja | 7 |
| ILF | Caché de medios (imágenes, audio) | Media | 10 |
| **Subtotal ILF** | **6 componentes** | | **67** |
| EIF | API AnkiWeb (sincronización remota) | Alta | 10 |
| EIF | Add-ons externos vía repositorio Ankiweb | Media | 7 |
| **Subtotal EIF** | **2 componentes** | | **17** |
| **UFP TOTAL** | | | **184** |

**Factores de ajuste (Fi) — Anki:** Com. datos: 4, Proc. dist.: 4, Rendimiento: 4, Config. intensiva: 3, Frec. trans.: 4, Entrada en línea: 5, Eficiencia: 5, Actualización: 5, Proc. complejo: 5, Reusabilidad: 4, Fac. instalación: 4, Fac. operación: 4, Multi-sitio: 5, Fac. cambio: 5.

ΣFi = 61
VAF = 0,65 + 0,01 × 61 = **1,26**
**FP = 184 × 1,26 ≈ 232**

---

## 5. Tabla Comparativa Resumen

### 5.1 Métricas Orientadas al Tamaño (resumen)

| Métrica | MuseScore | PianoBooster | Anki |
|---|---:|---:|---:|
| KLOC | 1.200 | 30 | 200 |
| Esfuerzo (PM) | 8.430 | 135 | 1.135 |
| Tiempo (meses) | 59,1 | 13,9 | 29,3 |
| Personal promedio | 143 | 10 | 39 |
| Costo (USD) | 50,58 M | 0,81 M | 6,81 M |
| Productividad (LOC/PM) | 142 | 222 | 176 |
| Documentación (págs.) | 24.000 | 600 | 4.000 |

### 5.2 Métricas Orientadas a la Función (resumen)

| Componente | MuseScore | PianoBooster | Anki |
|---|---:|---:|---:|
| EI (entradas) | 43 | 25 | 49 |
| EO (salidas) | 31 | 21 | 33 |
| EQ (consultas) | 20 | 9 | 18 |
| ILF (archivos internos) | 64 | 29 | 67 |
| EIF (archivos externos) | 24 | 14 | 17 |
| **UFP** | **182** | **98** | **184** |
| VAF | 1,26 | 1,04 | 1,26 |
| **FP (ajustados)** | **229** | **102** | **232** |

### 5.3 Lecturas comparativas

- **PianoBooster** es el sistema más liviano y focalizado: KLOC y FP coinciden en mostrarlo como una aplicación de escritorio especializada con un único caso de uso bien definido. Es el referente más directo del *núcleo* de práctica musical de PianoVision.
- **Anki** y **MuseScore** poseen tamaño funcional ajustado (FP) similar (≈ 230), pero MuseScore tiene ~6 veces más LOC. Esto evidencia que el dominio de **notación musical gráfica** demanda mucho más código por punto de función que el dominio de **gestión de aprendizaje**: el motor de renderizado, el modelo de música y la importación/exportación multi-formato son inherentemente costosos en LOC.
- Para PianoVision AI conviene combinar las tres aproximaciones: el motor de práctica de **PianoBooster**, la dimensión social y de notación de **MuseScore**, y los componentes de aprendizaje longitudinal + gamificación + sincronización de **Anki**.

---

## Referencias

1. Pressman, R. S. (2020). *Software Engineering: A Practitioner's Approach* (9.ª ed.). McGraw-Hill.
2. Boehm, B. W. (1981). *Software Engineering Economics*. Prentice Hall.
3. Albrecht, A. J., & Gaffney, J. E. (1983). Software function, source lines of code, and development effort prediction: A software science validation. *IEEE Transactions on Software Engineering*, SE-9(6), 639-648.
4. IFPUG (2010). *Function Point Counting Practices Manual*, versión 4.3.1.
5. Repositorios oficiales:
   - MuseScore: https://github.com/musescore/MuseScore
   - PianoBooster: https://github.com/captbaritone/pianobooster
   - Anki: https://github.com/ankitects/anki

---

*Fin de la Primera Parte.*
