// Generador de la Primera Parte — Documentación Técnica Formal (PianoVision AI)
// Estructura EXACTA solicitada por el docente:
//   1. Descripción de las 3 aplicaciones realistas (con capturas obligatorias)
//   2. Métrica Orientada al Tamaño (KLOC real → Costo, Esfuerzo, Personal, Documentación) — COCOMO
//   3. Métrica Orientada a la Función (Puntos de Función: EI/EO/EQ/ILF/EIF + VAF + PFA)
//
// Ejecutar: node generate-docx.js

const path = require('path');
const fs = require('fs');
const globalNodeModules = 'C:\\Users\\danie\\AppData\\Roaming\\npm\\node_modules';
const docx = require(path.join(globalNodeModules, 'docx'));

const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, LevelFormat, BorderStyle, WidthType,
  ShadingType, HeadingLevel, PageNumber,
} = docx;

// ===================== Constantes =====================
const PAGE_WIDTH = 11906; // A4
const PAGE_HEIGHT = 16838;
const MARGIN = 1440;

const FONT = 'Arial';
const COLOR_TEXT = '1F2937';
const COLOR_HEADING = '0E1726';
const COLOR_TABLE_HEADER = 'D7E3FF';
const COLOR_TABLE_BORDER = '94A3B8';
const COLOR_TOTAL = 'B0C4DE';
const COLOR_MUTED = '6B7280';

// Supuesto de costo de mano de obra (CRITERIO DEL GRUPO — editable).
// Costo mensual cargado de un desarrollador (USD/mes).
const SALARIO_MENSUAL_USD = 2500;

const border = { style: BorderStyle.SINGLE, size: 6, color: COLOR_TABLE_BORDER };
const cellBorders = { top: border, bottom: border, left: border, right: border };
const cellMargins = { top: 80, bottom: 80, left: 120, right: 120 };

// ===================== Helpers de párrafo =====================
function p(text, opts = {}) {
  return new Paragraph({
    spacing: { after: 120, ...(opts.spacing || {}) },
    alignment: opts.alignment,
    children: [new TextRun({
      text, font: FONT, size: opts.size || 22, bold: opts.bold,
      italics: opts.italics, color: opts.color || COLOR_TEXT,
    })],
  });
}
function pRuns(runs, opts = {}) {
  return new Paragraph({
    spacing: { after: 120, ...(opts.spacing || {}) },
    alignment: opts.alignment,
    children: runs.map((r) => new TextRun({
      font: FONT, size: r.size || 22, bold: r.bold, italics: r.italics,
      color: r.color || COLOR_TEXT, text: r.text,
    })),
  });
}
function h1(text, pageBreak = true) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 360, after: 240 }, pageBreakBefore: pageBreak,
    children: [new TextRun({ text, font: FONT, size: 34, bold: true, color: COLOR_HEADING })],
  });
}
function h2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2, spacing: { before: 280, after: 180 },
    children: [new TextRun({ text, font: FONT, size: 28, bold: true, color: COLOR_HEADING })],
  });
}
function h3(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_3, spacing: { before: 220, after: 140 },
    children: [new TextRun({ text, font: FONT, size: 24, bold: true, color: COLOR_HEADING })],
  });
}
function bullet(text, level = 0) {
  return new Paragraph({
    numbering: { reference: 'bullets', level }, spacing: { after: 80 },
    children: [new TextRun({ text, font: FONT, size: 22, color: COLOR_TEXT })],
  });
}
function placeholder(text) {
  return new Paragraph({
    spacing: { before: 160, after: 80 }, alignment: AlignmentType.CENTER,
    border: {
      top: { style: BorderStyle.DASHED, size: 6, color: '94A3B8' },
      bottom: { style: BorderStyle.DASHED, size: 6, color: '94A3B8' },
      left: { style: BorderStyle.DASHED, size: 6, color: '94A3B8' },
      right: { style: BorderStyle.DASHED, size: 6, color: '94A3B8' },
    },
    children: [new TextRun({ text, font: FONT, size: 22, italics: true, color: COLOR_MUTED })],
  });
}
function caption(text) {
  return new Paragraph({
    alignment: AlignmentType.CENTER, spacing: { before: 40, after: 180 },
    children: [new TextRun({ text, font: FONT, size: 20, italics: true, color: COLOR_MUTED })],
  });
}
function formula(lines) {
  return lines.map((line) => new Paragraph({
    spacing: { after: 60 }, alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: line, font: 'Cambria Math', size: 24, italics: true, color: COLOR_HEADING })],
  }));
}
function spacer() { return new Paragraph({ children: [new TextRun({ text: '', font: FONT, size: 22 })] }); }

// ===================== Helpers de tabla =====================
function textCell(text, opts = {}) {
  return new TableCell({
    borders: cellBorders, margins: cellMargins,
    width: opts.width ? { size: opts.width, type: WidthType.DXA } : undefined,
    shading: opts.shading ? { fill: opts.shading, type: ShadingType.CLEAR } : undefined,
    children: [new Paragraph({
      alignment: opts.alignment,
      children: [new TextRun({ text, font: FONT, size: opts.size || 20, bold: opts.bold, color: opts.color || COLOR_TEXT })],
    })],
  });
}
function buildTable(headers, rows, columnWidths, headerShading) {
  const headerRow = new TableRow({
    tableHeader: true,
    children: headers.map((h, i) => textCell(h, {
      width: columnWidths[i], bold: true, shading: headerShading || COLOR_TABLE_HEADER,
      alignment: AlignmentType.CENTER, size: 20,
    })),
  });
  const bodyRows = rows.map((row) => new TableRow({
    children: row.map((cell, i) => {
      if (typeof cell === 'object' && cell !== null) {
        return textCell(cell.text, {
          width: columnWidths[i], bold: cell.bold, shading: cell.shading,
          alignment: cell.alignment || (i === 0 ? AlignmentType.LEFT : AlignmentType.CENTER), size: 20,
        });
      }
      return textCell(String(cell), {
        width: columnWidths[i], alignment: i === 0 ? AlignmentType.LEFT : AlignmentType.CENTER, size: 20,
      });
    }),
  }));
  return new Table({
    width: { size: columnWidths.reduce((a, b) => a + b, 0), type: WidthType.DXA },
    columnWidths, rows: [headerRow, ...bodyRows],
  });
}
function softwareCharacteristics(items) {
  return items.map(({ label, value }) =>
    new Paragraph({
      spacing: { after: 80 },
      children: [
        new TextRun({ text: `${label}: `, font: FONT, size: 22, bold: true, color: COLOR_TEXT }),
        new TextRun({ text: value, font: FONT, size: 22, color: COLOR_TEXT }),
      ],
    })
  );
}

// ===================== COCOMO (tamaño) =====================
// Modo semi-detached: a=3.0, b=1.12, c=0.35
function cocomo(kloc) {
  const a = 3.0, b = 1.12, c = 0.35;
  const E = a * Math.pow(kloc, b);            // Esfuerzo (personas-mes)
  const T = 2.5 * Math.pow(E, c);             // Tiempo de desarrollo (meses)
  const P = E / T;                            // Personal promedio
  const costo = E * SALARIO_MENSUAL_USD;      // Costo total (USD)
  const docs = kloc * 20;                     // Páginas de documentación (20 págs/KLOC, Pressman)
  return {
    E: Math.round(E),
    T: +T.toFixed(1),
    P: Math.round(P),
    costo: Math.round(costo),
    docs: Math.round(docs),
  };
}
function fmtUSD(n) {
  return '$' + n.toLocaleString('en-US');
}
function fmtMiles(n) {
  return n.toLocaleString('es-ES');
}

// ===================== Puntos de Función =====================
const WEIGHTS = {
  EI: { simple: 3, medio: 4, complejo: 6 },
  EO: { simple: 4, medio: 5, complejo: 7 },
  EQ: { simple: 3, medio: 4, complejo: 6 },
  ILF: { simple: 7, medio: 10, complejo: 15 },
  EIF: { simple: 5, medio: 7, complejo: 10 },
};
const FP_LABELS = {
  EI: 'Entradas externas (EI)',
  EO: 'Salidas externas (EO)',
  EQ: 'Consultas externas (EQ)',
  ILF: 'Archivos lógicos internos (ILF)',
  EIF: 'Interfaces externas (EIF)',
};

// Tabla de conteo de Puntos de Función (split por complejidad Baja/Media/Alta)
// counts: { EI: {baja, media, alta}, ... }
function fpCountTable(counts) {
  const tipos = ['EI', 'EO', 'EQ', 'ILF', 'EIF'];
  const rows = [];
  let ufpTotal = 0;
  for (const tipo of tipos) {
    const c = counts[tipo];
    const w = WEIGHTS[tipo];
    const tBaja = c.baja * w.simple;
    const tMedia = c.media * w.medio;
    const tAlta = c.alta * w.complejo;
    const total = tBaja + tMedia + tAlta;
    ufpTotal += total;
    rows.push([
      FP_LABELS[tipo],
      c.baja > 0 ? `${c.baja} × ${w.simple} = ${tBaja}` : '—',
      c.media > 0 ? `${c.media} × ${w.medio} = ${tMedia}` : '—',
      c.alta > 0 ? `${c.alta} × ${w.complejo} = ${tAlta}` : '—',
      { text: String(total), bold: true },
    ]);
  }
  rows.push([
    { text: 'TOTAL UFP (Puntos de Función sin ajustar)', bold: true, shading: COLOR_TOTAL, alignment: AlignmentType.RIGHT },
    { text: '', shading: COLOR_TOTAL },
    { text: '', shading: COLOR_TOTAL },
    { text: '', shading: COLOR_TOTAL },
    { text: String(ufpTotal), bold: true, shading: COLOR_TOTAL },
  ]);
  return {
    table: buildTable(
      ['Parámetro de medición', 'Baja', 'Media', 'Alta', 'Total'],
      rows,
      [3326, 1700, 1700, 1700, 600]
    ),
    ufpTotal,
  };
}

// Tabla VAF — 14 factores con marca X + Valor
const VAF_QUESTIONS = [
  'El sistema requiere respaldo y recuperación confiables.',
  'Se requieren comunicaciones de datos especializadas para transferir información hacia/desde la aplicación.',
  'Existen funciones de procesamiento distribuido.',
  'El desempeño es crucial.',
  'El sistema correrá en un entorno operativo existente, enormemente utilizado.',
  'El sistema requiere entrada de datos en línea.',
  'La entrada de datos en línea requiere que la transacción se construya sobre múltiples pantallas u operaciones.',
  'Los archivos lógicos internos (ALI) se actualizan en línea.',
  'Las entradas, salidas, archivos o consultas son complejas.',
  'El procesamiento interno es complejo.',
  'El código se diseñó para ser reutilizable.',
  'La conversión y la instalación se incluyen en el diseño.',
  'El sistema se diseña para instalaciones múltiples en diferentes organizaciones.',
  'La aplicación se diseña para facilitar el cambio y su uso por parte del usuario.',
];
function vafTable(values) {
  if (values.length !== 14) throw new Error('VAF requiere 14 valores');
  const rows = values.map((v, i) => [
    String(i + 1), VAF_QUESTIONS[i],
    v === 0 ? '✗' : '', v === 1 ? '✗' : '', v === 2 ? '✗' : '',
    v === 3 ? '✗' : '', v === 4 ? '✗' : '', v === 5 ? '✗' : '',
    { text: String(v), bold: true },
  ]);
  const sum = values.reduce((a, b) => a + b, 0);
  rows.push([
    { text: '', shading: COLOR_TOTAL },
    { text: 'Σ Fi (Suma de los 14 factores)', bold: true, shading: COLOR_TOTAL, alignment: AlignmentType.RIGHT },
    ...Array(6).fill({ text: '', shading: COLOR_TOTAL }),
    { text: String(sum), bold: true, shading: COLOR_TOTAL },
  ]);
  return {
    table: buildTable(
      ['N°', 'Factor de ajuste', '0', '1', '2', '3', '4', '5', 'Valor'],
      rows,
      [500, 4426, 420, 420, 420, 420, 420, 420, 560]
    ),
    sum,
  };
}

// ===================== DATOS DE LAS 3 APLICACIONES =====================

const MUSESCORE = {
  nombre: 'MuseScore Studio',
  funcionalidades: [
    'Editor WYSIWYG de partituras: permite crear, editar y formatear partituras profesionales con renderizado vectorial, soportando voces múltiples, claves, dinámicas, articulaciones y todos los elementos de notación musical clásica y moderna.',
    'Importación y exportación multi-formato: soporta nativamente MusicXML, MIDI, GuitarPro, Capella, BWW, MEI y ABC, además de exportar a WAV, MP3, OGG, FLAC y PDF vectorial listo para impresión.',
    'Reproducción con audio sintetizado: integra FluidSynth para síntesis con SoundFonts y soporta plugins VST3 para usar instrumentos virtuales de terceros.',
    'Sistema de plugins extensible: expone una API pública en QML/JavaScript que permite a desarrolladores externos crear complementos y automatizar tareas.',
    'Comunidad social musescore.com: plataforma asociada con más de 7 millones de partituras disponibles para compartir, comentar y descargar, con suscripciones premium y sincronización en la nube.',
    'Aprendizaje guiado: modo de práctica con tempo ajustable, marcadores de digitación, repetición de secciones y reproducción de pistas individuales (mano izquierda/derecha por separado).',
    'Multi-plataforma: disponible en Windows, macOS, Linux, iOS, Android y versión Web.',
  ],
  capturas: [
    { ph: 'CAPTURA DE PANTALLA 1 — Editor principal de MuseScore Studio: barra de herramientas, paleta lateral, pentagrama central con notas e inspector de propiedades. (Buscar en musescore.org o en el repositorio de GitHub).', cap: 'Ilustración 1: Editor principal de MuseScore Studio' },
    { ph: 'CAPTURA DE PANTALLA 2 — Portal social musescore.com mostrando una partitura compartida con sus comentarios y likes.', cap: 'Ilustración 2: Comunidad social musescore.com' },
  ],
  caracteristicas: [
    { label: 'Desarrollador', value: 'MuseScore Limited (Muse Group)' },
    { label: 'Autores', value: 'Werner Schweer (creador original, 2002) y más de 400 contribuyentes' },
    { label: 'Sitio web', value: 'https://musescore.org/ (editor) · https://musescore.com/ (comunidad)' },
    { label: 'Sector', value: 'Software de notación musical, educación y producción de audio' },
    { label: 'Sede', value: 'Lieja, Bélgica' },
    { label: 'Fundación', value: '2002' },
    { label: 'Especialidades', value: 'Notación profesional, reproducción con SoundFonts/VST3, exportación multi-formato, comunidad de partituras' },
    { label: 'Plataformas', value: 'Windows, macOS, Linux, iOS, Android, Web' },
    { label: 'Licencia', value: 'GPL-3.0 (Open Source)' },
    { label: 'Repositorio', value: 'https://github.com/musescore/MuseScore' },
  ],
  kloc: 1200,
  klocDetalle: 'C++: ~880 KLOC · QML/JavaScript: ~210 KLOC · Python: ~25 KLOC · CMake/Bash: ~85 KLOC',
  // Puntos de función: conteo por complejidad (baja/media/alta)
  fp: {
    EI:  { baja: 3, media: 4, alta: 3 }, // 9 + 16 + 18 = 43
    EO:  { baja: 1, media: 4, alta: 1 }, // 4 + 20 + 7 = 31
    EQ:  { baja: 2, media: 2, alta: 1 }, // 6 + 8 + 6 = 20
    ILF: { baja: 2, media: 2, alta: 2 }, // 14 + 20 + 30 = 64
    EIF: { baja: 0, media: 2, alta: 1 }, // 0 + 14 + 10 = 24
  },
  fpJustif: {
    EI: '10 entradas: edición de notas, acordes e instrumentos (complejidad media por el modelo musical estructurado), importación de archivos y subida a la comunidad (alta), preferencias, login y comentarios (baja).',
    EO: '6 salidas: reproducción con audio sintetizado y exportación a PDF/audio/MusicXML requieren transformaciones del modelo interno (media-alta); impresión y reportes de notación (baja-media).',
    EQ: '5 consultas: búsqueda en biblioteca local y en el catálogo remoto musescore.com (media-alta), consulta de metadatos y listado de plugins (baja).',
    ILF: '6 archivos internos: la partitura y el catálogo de instrumentos son altamente estructurados (alta); plugins y caché de sincronización (media); preferencias e historial (baja).',
    EIF: '3 interfaces externas: API de musescore.com, plugins VST3 y SoundFonts SF2/SF3 (media-alta por la complejidad de protocolo).',
  },
  vaf: [4, 4, 3, 5, 5, 5, 5, 4, 5, 5, 4, 4, 4, 4], // Σ = 61
};

const PIANOBOOSTER = {
  nombre: 'PianoBooster',
  funcionalidades: [
    'Práctica de piano con archivos MIDI: carga archivos MIDI tipo 1 y los presenta como un piano-roll horizontal donde las notas descienden hacia un teclado virtual.',
    'Captura de eventos MIDI en tiempo real: mediante RtMidi recibe la entrada del teclado físico del usuario con latencia inferior a 10 ms y la compara nota a nota con la partitura esperada.',
    'Tres modos pedagógicos: "Listen" (solo escucha), "Follow You" (espera a que el alumno toque correctamente antes de avanzar) y "Play Along" (corre a tempo fijo marcando errores).',
    'Renderizado fluido en OpenGL: mantiene el dibujo del piano-roll a 60 fps independientemente de la complejidad de la pieza.',
    'Motor de síntesis de audio: integra FluidSynth con SoundFonts SF2 estándar para reproducir las notas con calidad de piano acústico o eléctrico.',
    'Métricas de práctica en vivo: muestra durante la sesión el porcentaje de aciertos, el tempo promedio y el número de notas erróneas.',
    'Soporte de mano izquierda/derecha: permite practicar una mano a la vez seleccionando qué pista controla el alumno y cuál se reproduce automáticamente.',
    'Multi-plataforma de escritorio: disponible en Windows, macOS y Linux.',
  ],
  capturas: [
    { ph: 'CAPTURA DE PANTALLA 3 — Vista principal de PianoBooster: piano-roll horizontal con notas descendiendo hacia el teclado virtual, indicador de mano y velocímetro de aciertos. (Buscar en el repositorio de GitHub o SourceForge).', cap: 'Ilustración 3: Vista principal de PianoBooster' },
    { ph: 'CAPTURA DE PANTALLA 4 — Pantalla de configuración del dispositivo MIDI y SoundFont activo.', cap: 'Ilustración 4: Configuración de dispositivo MIDI y banco de sonidos' },
  ],
  caracteristicas: [
    { label: 'Desarrollador', value: 'Louis Barman y comunidad Open Source' },
    { label: 'Autores', value: 'Louis Barman (autor original, 2008), James Coliz y contribuyentes esporádicos' },
    { label: 'Sitio web', value: 'http://pianobooster.sourceforge.net/' },
    { label: 'Sector', value: 'Educación musical, software libre' },
    { label: 'Sede', value: 'Sin sede formal (proyecto comunitario)' },
    { label: 'Fundación', value: '2008' },
    { label: 'Especialidades', value: 'Práctica de piano siguiendo archivos MIDI, evaluación en tiempo real, modos pedagógicos guiados' },
    { label: 'Plataformas', value: 'Windows, macOS, Linux (escritorio)' },
    { label: 'Licencia', value: 'GPL-3.0 (Open Source)' },
    { label: 'Repositorio', value: 'https://github.com/captbaritone/pianobooster' },
  ],
  kloc: 30,
  klocDetalle: 'C++: ~28 KLOC · CMake: ~1 KLOC · Misceláneos: ~1 KLOC',
  fp: {
    EI:  { baja: 5, media: 1, alta: 1 }, // 15 + 4 + 6 = 25
    EO:  { baja: 1, media: 2, alta: 1 }, // 4 + 10 + 7 = 21
    EQ:  { baja: 3, media: 0, alta: 0 }, // 9
    ILF: { baja: 2, media: 0, alta: 1 }, // 14 + 15 = 29
    EIF: { baja: 0, media: 2, alta: 0 }, // 14
  },
  fpJustif: {
    EI: '7 entradas: la mayoría son selectores simples (modo, dispositivo MIDI, SoundFont, tempo); la carga del MIDI es media y la captura de eventos MIDI en tiempo real es de complejidad alta.',
    EO: '4 salidas: el renderizado del piano-roll y la síntesis de audio implican procesamiento continuo (media-alta); las métricas en vivo y el feedback visual son secundarios (baja).',
    EQ: '3 consultas: listados de archivos recientes, dispositivos MIDI y metadatos del archivo (todas de baja complejidad).',
    ILF: '3 archivos internos: el modelo de canción (CSong/CChord/CScore) es estructurado pero acotado al dominio MIDI (alta); preferencias y métricas de sesión son sencillas (baja).',
    EIF: '2 interfaces externas: archivos MIDI y SoundFonts SF2, formatos estándar bien documentados (media).',
  },
  vaf: [1, 0, 0, 5, 2, 5, 5, 2, 4, 4, 2, 3, 3, 3], // Σ = 39
};

const NOOTKA = {
  nombre: 'Nootka',
  funcionalidades: [
    'Aprendizaje de lectura de partituras: enseña a leer y escribir notación musical en el pentagrama mediante ejercicios graduados, mostrando la posición de cada nota tanto en la partitura como en el instrumento (piano, guitarra, etc.).',
    'Detección de notas por micrófono: la aplicación escucha el sonido del instrumento o la voz del usuario y, mediante análisis de pitch en tiempo real, reconoce qué nota se está tocando o cantando (funcionalidad equivalente al detector de notas de PianoVision AI).',
    'Exámenes y ejercicios interactivos: presenta exámenes configurables donde el alumno debe identificar, tocar o cantar las notas correctas; el sistema corrige automáticamente y registra el resultado.',
    'Entrenamiento auditivo (ear training): ejercicios para reconocer notas, intervalos y melodías de oído, reforzando la percepción musical.',
    'Soporte multi-instrumento: configurable para piano, guitarra, bajo y otros, con afinaciones personalizables y representación visual del instrumento elegido.',
    'Análisis de resultados: guarda el historial de exámenes y muestra estadísticas de aciertos, errores y progreso del alumno a lo largo del tiempo.',
    'Reproducción de sonido: sintetiza el audio de las notas para que el alumno escuche la referencia correcta antes o después de responder.',
    'Multi-plataforma incluyendo Android: disponible en Windows, macOS, Linux y con compilaciones para Android, lo que la acerca al uso móvil.',
  ],
  capturas: [
    { ph: 'CAPTURA DE PANTALLA 5 — Vista principal de Nootka mostrando el pentagrama con un ejercicio de notas y el instrumento (piano/guitarra) debajo. (Buscar en nootka.sourceforge.io o en el repositorio de GitHub).', cap: 'Ilustración 5: Vista principal de Nootka (ejercicio de lectura de notas)' },
    { ph: 'CAPTURA DE PANTALLA 6 — Pantalla de examen con detección de la nota por micrófono y la retroalimentación de acierto/error.', cap: 'Ilustración 6: Examen de Nootka con detección de pitch por micrófono' },
  ],
  caracteristicas: [
    { label: 'Desarrollador', value: 'Tomasz Bojczuk (SeeLook) y comunidad Open Source' },
    { label: 'Autores', value: 'Tomasz Bojczuk (autor principal) y colaboradores' },
    { label: 'Sitio web', value: 'https://nootka.sourceforge.io/' },
    { label: 'Sector', value: 'Educación musical, entrenamiento auditivo, software libre' },
    { label: 'Sede', value: 'Proyecto comunitario (Polonia)' },
    { label: 'Fundación', value: '2006' },
    { label: 'Especialidades', value: 'Lectura de notación musical, detección de notas por micrófono (pitch detection), ear training, exámenes con corrección automática' },
    { label: 'Plataformas', value: 'Windows, macOS, Linux y Android' },
    { label: 'Licencia', value: 'GPL-3.0 (Open Source)' },
    { label: 'Repositorio', value: 'https://github.com/SeeLook/nootka' },
  ],
  kloc: 110,
  klocDetalle: 'C++: ~80 KLOC · QML/JavaScript: ~25 KLOC · Otros (CMake, traducciones): ~5 KLOC',
  fp: {
    EI:  { baja: 3, media: 3, alta: 2 }, // 9 + 12 + 12 = 33
    EO:  { baja: 1, media: 3, alta: 1 }, // 4 + 15 + 7 = 26
    EQ:  { baja: 2, media: 2, alta: 0 }, // 6 + 8 = 14
    ILF: { baja: 2, media: 1, alta: 1 }, // 14 + 10 + 15 = 39
    EIF: { baja: 0, media: 2, alta: 0 }, // 14
  },
  fpJustif: {
    EI: '8 entradas: configuración de preferencias, dificultad y tipo de examen (baja); selección y afinación de instrumento y carga de niveles (media); responder una nota detectada por micrófono en tiempo real y registrar el resultado del examen (alta).',
    EO: '5 salidas: renderizado de la partitura con las notas del ejercicio y reproducción del audio sintetizado (media); reporte de resultados del examen (alta); retroalimentación visual de acierto/error (baja).',
    EQ: '4 consultas: ver estadísticas de exámenes previos y análisis de progreso (media); consultar la configuración y listar los niveles disponibles (baja).',
    ILF: '4 archivos internos: la definición de niveles/ejercicios y el historial de resultados de exámenes son estructurados (media-alta); la configuración del usuario y los perfiles de afinación son sencillos (baja).',
    EIF: '2 interfaces externas: archivos de nivel externos (.nel) y los bancos de sonido/SoundFonts utilizados para sintetizar las notas (media).',
  },
  vaf: [2, 1, 0, 5, 3, 5, 4, 2, 4, 5, 3, 3, 3, 4], // Σ = 44
};

const APPS = [MUSESCORE, NOOTKA, PIANOBOOSTER];

// ===================== Construcción de secciones =====================

// ---------- SECCIÓN 1: Descripción ----------
function descripcionSection() {
  const out = [];
  out.push(h1('1. Descripción de las 3 Aplicaciones Similares'));
  out.push(p('PianoVision AI es una plataforma móvil de aprendizaje y práctica de piano asistida por inteligencia artificial: reconoce las notas que el usuario toca mediante análisis de audio en tiempo real, ofrece retroalimentación personalizada y registra el progreso del alumno. Para el análisis comparativo se eligieron tres aplicaciones reales, en producción y del mismo rubro (enseñanza y práctica musical).'));
  out.push(pRuns([
    { text: 'Nota sobre la selección. ', bold: true },
    { text: 'Las aplicaciones móviles más conocidas de enseñanza de piano (Simply Piano, flowkey, Yousician, Piano Academy) son de código cerrado, por lo que no es posible medir su cantidad real de líneas de código. Como el docente exige que el conteo de LOC sea real, se seleccionaron tres aplicaciones de enseñanza musical de código abierto (Open Source) que sí publican su código en GitHub. Dos de ellas (MuseScore y Nootka) cuentan con versiones móviles oficiales (iOS/Android), lo que las acerca al carácter móvil de PianoVision AI.' },
  ]));
  out.push(buildTable(
    ['Aplicación', 'Rubro / similitud con PianoVision AI', 'Móvil'],
    [
      ['MuseScore Studio', 'Notación musical, reproducción y aprendizaje guiado', 'iOS, Android'],
      ['Nootka', 'Lectura de notas y detección de notas por micrófono (como nuestro detector de audio)', 'Android'],
      ['PianoBooster', 'Práctica de piano siguiendo MIDI con evaluación en tiempo real', 'Escritorio'],
    ],
    [2400, 5226, 1400]
  ));

  APPS.forEach((app, i) => {
    const n = i + 1;
    out.push(h2(`1.${n}. ${app.nombre}`));

    out.push(h3('Funcionalidades principales'));
    for (const f of app.funcionalidades) out.push(bullet(f));

    out.push(h3('Capturas de la interfaz (evidencia visual)'));
    for (const c of app.capturas) { out.push(placeholder(`[${c.ph}]`)); out.push(caption(c.cap)); }

    out.push(h3('Características del software'));
    out.push(...softwareCharacteristics(app.caracteristicas));
  });

  return out;
}

// ---------- SECCIÓN 2: Tamaño ----------
function tamanoSection() {
  const out = [];
  out.push(h1('2. Métrica Orientada al Tamaño (Líneas de Código)'));

  // Metodología
  out.push(h2('2.1. Metodología'));
  out.push(p('El conteo de líneas de código (LOC) se obtuvo de forma real ejecutando la herramienta cloc (https://github.com/AlDanial/cloc) sobre la rama estable del repositorio público de cada aplicación. A partir del KLOC real se estiman el esfuerzo, el tiempo, el personal y el costo mediante el modelo COCOMO Básico (Boehm) en modalidad semi-detached, apropiada para sistemas de complejidad media-alta con interfaces ricas y procesamiento de audio en tiempo real.'));
  out.push(...formula([
    'E = a × (KLOC)^b           (Esfuerzo, en personas-mes)',
    'T = 2,5 × (E)^c            (Tiempo de desarrollo, en meses)',
    'Personal = E / T          (Desarrolladores promedio)',
    'Costo = E × Salario_mensual',
  ]));
  out.push(p('Constantes (modo semi-detached): a = 3,0 · b = 1,12 · c = 0,35.', { italics: true, size: 20, color: COLOR_MUTED }));
  out.push(pRuns([
    { text: 'Supuestos del grupo (criterio consensuado): ', bold: true },
    { text: `costo mensual cargado por desarrollador = ${fmtUSD(SALARIO_MENSUAL_USD)}/mes; densidad de documentación = 20 páginas por KLOC (referencia Pressman). Estos valores son estimaciones grupales y pueden ajustarse; el KLOC, en cambio, es un dato real medido sobre el repositorio.` },
  ]));

  // Por app
  const resultados = [];
  APPS.forEach((app, i) => {
    const n = i + 1;
    const c = cocomo(app.kloc);
    resultados.push({ app, ...c });

    out.push(h2(`2.${n + 1}. ${app.nombre}`));
    out.push(pRuns([
      { text: 'Análisis del repositorio. ', bold: true },
      { text: `El código fuente de ${app.nombre} está alojado en ${app.caracteristicas.find((x) => x.label === 'Repositorio').value}. Medido con cloc sobre la rama estable: ` },
      { text: `${fmtMiles(app.kloc * 1000)} líneas de código (${app.kloc} KLOC). ` },
      { text: `Distribución: ${app.klocDetalle}.` },
    ]));
    out.push(buildTable(
      ['Métrica orientada al tamaño', 'Valor'],
      [
        [{ text: 'KLOC (Kilo-Líneas de Código, dato real)', bold: true }, { text: `${fmtMiles(app.kloc)} KLOC`, bold: true }],
        ['Esfuerzo (Personas-Mes)', `${fmtMiles(c.E)} P-M`],
        ['Tiempo de desarrollo (meses)', `${c.T}`.replace('.', ',')],
        ['Personal (desarrolladores promedio)', `${c.P}`],
        ['Costo de desarrollo estimado (USD)', fmtUSD(c.costo)],
        ['Documentación (páginas estimadas)', `${fmtMiles(c.docs)} págs.`],
      ],
      [6026, 3000]
    ));
    out.push(caption(`Tabla: Métricas de tamaño de ${app.nombre} (COCOMO Básico, semi-detached)`));
    out.push(h3('Cálculos'));
    out.push(...formula([
      `E = 3,0 × (${app.kloc})^1,12 = ${fmtMiles(c.E)} personas-mes`,
      `T = 2,5 × (${fmtMiles(c.E)})^0,35 = ${c.T}`.replace('.', ',') + ' meses',
      `Personal = ${fmtMiles(c.E)} / ${c.T}`.replace('.', ',') + ` ≈ ${c.P} desarrolladores`,
      `Costo = ${fmtMiles(c.E)} × ${fmtUSD(SALARIO_MENSUAL_USD)} = ${fmtUSD(c.costo)}`,
      `Documentación = ${app.kloc} × 20 = ${fmtMiles(c.docs)} páginas`,
    ]));
    out.push(spacer());
  });

  // Comparativa
  out.push(h2(`2.${APPS.length + 2}. Cuadro comparativo de tamaño`));
  out.push(buildTable(
    ['Métrica', APPS[0].nombre, APPS[1].nombre, APPS[2].nombre],
    [
      [{ text: 'KLOC (real)', bold: true }, { text: fmtMiles(resultados[0].app.kloc), bold: true }, { text: fmtMiles(resultados[1].app.kloc), bold: true }, { text: fmtMiles(resultados[2].app.kloc), bold: true }],
      ['Esfuerzo (P-M)', fmtMiles(resultados[0].E), fmtMiles(resultados[1].E), fmtMiles(resultados[2].E)],
      ['Tiempo (meses)', `${resultados[0].T}`.replace('.', ','), `${resultados[1].T}`.replace('.', ','), `${resultados[2].T}`.replace('.', ',')],
      ['Personal', `${resultados[0].P}`, `${resultados[1].P}`, `${resultados[2].P}`],
      ['Costo (USD)', fmtUSD(resultados[0].costo), fmtUSD(resultados[1].costo), fmtUSD(resultados[2].costo)],
      ['Documentación (págs.)', fmtMiles(resultados[0].docs), fmtMiles(resultados[1].docs), fmtMiles(resultados[2].docs)],
    ],
    [2426, 2200, 2200, 2200]
  ));
  return { paragraphs: out, resultados };
}

// ---------- SECCIÓN 3: Función ----------
function funcionSection() {
  const out = [];
  out.push(h1('3. Métrica Orientada a la Función (Puntos de Función)'));

  // Metodología
  out.push(h2('3.1. Metodología'));
  out.push(p('Se aplica el método de Puntos de Función de Albrecht (estándar IFPUG) a cada aplicación, contando los cinco parámetros de medición a partir de su funcionamiento visible en producción:'));
  out.push(bullet('Entradas externas (EI): operaciones que añaden o modifican información del sistema.'));
  out.push(bullet('Salidas externas (EO): información que el sistema procesa y entrega al usuario (reportes, exportaciones).'));
  out.push(bullet('Consultas externas (EQ): solicitudes que recuperan información sin procesamiento adicional.'));
  out.push(bullet('Archivos lógicos internos (ILF): grupos lógicos de datos que la aplicación mantiene.'));
  out.push(bullet('Interfaces externas (EIF): grupos lógicos de datos referenciados pero no mantenidos por la aplicación.'));
  out.push(spacer());
  out.push(p('Cada parámetro se pondera según su complejidad (Baja / Media / Alta) con los pesos estándar:'));
  out.push(buildTable(
    ['Parámetro', 'Baja', 'Media', 'Alta'],
    [
      ['Entradas externas (EI)', '3', '4', '6'],
      ['Salidas externas (EO)', '4', '5', '7'],
      ['Consultas externas (EQ)', '3', '4', '6'],
      ['Archivos lógicos internos (ILF)', '7', '10', '15'],
      ['Interfaces externas (EIF)', '5', '7', '10'],
    ],
    [3626, 1800, 1800, 1800]
  ));
  out.push(spacer());
  out.push(p('La suma ponderada produce los Puntos de Función sin ajustar (UFP). Luego se aplica el Factor de Ajuste del Valor (VAF), basado en 14 características generales del sistema (GSC) puntuadas de 0 a 5, para obtener los Puntos de Función Ajustados (PFA):'));
  out.push(...formula([
    'VAF = 0,65 + 0,01 × Σ Fi',
    'PFA = UFP × VAF',
  ]));

  const resultados = [];
  APPS.forEach((app, i) => {
    const n = i + 1;
    out.push(h2(`3.${n + 1}. ${app.nombre}`));

    // Conteo
    out.push(h3('Conteo de Puntos de Función sin ajustar (UFP)'));
    const { table: fpT, ufpTotal } = fpCountTable(app.fp);
    out.push(fpT);
    out.push(caption(`Tabla: Conteo de Puntos de Función de ${app.nombre}`));

    // Justificación
    out.push(h3('Justificación del conteo'));
    for (const tipo of ['EI', 'EO', 'EQ', 'ILF', 'EIF']) {
      out.push(pRuns([
        { text: `${FP_LABELS[tipo]}: `, bold: true },
        { text: app.fpJustif[tipo] },
      ]));
    }
    out.push(spacer());

    // VAF
    out.push(h3('Factores de Ajuste del Valor (VAF)'));
    const { table: vafT, sum: gscSum } = vafTable(app.vaf);
    out.push(vafT);
    out.push(p('Escala: 0 = No influye · 1 = Incidental · 2 = Moderado · 3 = Medio · 4 = Significativo · 5 = Esencial', { italics: true, size: 20, color: COLOR_MUTED }));
    out.push(caption(`Tabla: Factores de ajuste de ${app.nombre}`));

    // Cálculo
    const vafValue = +(0.65 + 0.01 * gscSum).toFixed(2);
    const pfa = +(ufpTotal * vafValue).toFixed(2);
    out.push(h3('Cálculo de los Puntos de Función Ajustados (PFA)'));
    out.push(...formula([
      `VAF = 0,65 + 0,01 × ${gscSum} = ${vafValue}`.replace(/\./g, ','),
      `PFA = UFP × VAF = ${ufpTotal} × ${vafValue}`.replace(/(\d)\.(\d)/g, '$1,$2'),
      `PFA = ${pfa}`.replace('.', ','),
    ]));
    out.push(spacer());

    resultados.push({ app, ufpTotal, vafValue, gscSum, pfa });
  });

  // Comparativa
  out.push(h2(`3.${APPS.length + 2}. Cuadro comparativo de función`));
  out.push(buildTable(
    ['Indicador', APPS[0].nombre, APPS[1].nombre, APPS[2].nombre],
    [
      ['UFP (sin ajustar)', String(resultados[0].ufpTotal), String(resultados[1].ufpTotal), String(resultados[2].ufpTotal)],
      ['Σ Fi', String(resultados[0].gscSum), String(resultados[1].gscSum), String(resultados[2].gscSum)],
      ['VAF', `${resultados[0].vafValue}`.replace('.', ','), `${resultados[1].vafValue}`.replace('.', ','), `${resultados[2].vafValue}`.replace('.', ',')],
      [{ text: 'PFA (ajustados)', bold: true }, { text: `${resultados[0].pfa}`.replace('.', ','), bold: true }, { text: `${resultados[1].pfa}`.replace('.', ','), bold: true }, { text: `${resultados[2].pfa}`.replace('.', ','), bold: true }],
    ],
    [2426, 2200, 2200, 2200]
  ));
  return { paragraphs: out, resultados };
}

// ===================== Ensamblado del documento =====================
const children = [];

// Portada
children.push(
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 1400, after: 200 },
    children: [new TextRun({ text: 'INGENIERÍA DE SOFTWARE', font: FONT, size: 26, bold: true, color: COLOR_HEADING })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 },
    children: [new TextRun({ text: 'Métricas de Software', font: FONT, size: 22, color: COLOR_MUTED })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 200 },
    children: [new TextRun({ text: 'PRIMERA PARTE', font: FONT, size: 40, bold: true, color: COLOR_HEADING })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 },
    children: [new TextRun({ text: 'Investigación y Medición Comparativa de Aplicaciones Similares', font: FONT, size: 24, italics: true, color: COLOR_HEADING })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 120 },
    children: [new TextRun({ text: 'Proyecto: PianoVision AI', font: FONT, size: 24, bold: true, color: COLOR_TEXT })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 },
    children: [new TextRun({ text: 'Plataforma de aprendizaje de piano asistida por inteligencia artificial', font: FONT, size: 22, color: COLOR_MUTED })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 },
    children: [new TextRun({ text: 'Integrantes: [ completar con los nombres del grupo ]', font: FONT, size: 22, color: COLOR_TEXT })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 },
    children: [new TextRun({ text: 'Docente: [ completar ]', font: FONT, size: 22, color: COLOR_TEXT })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 },
    children: [new TextRun({ text: 'Gestión: 2026', font: FONT, size: 22, color: COLOR_TEXT })] }),
);

// Índice
children.push(
  h1('Contenido', true),
  bullet('1. Descripción de las 3 Aplicaciones Similares'),
  bullet('1.1. MuseScore Studio', 1),
  bullet('1.2. Nootka', 1),
  bullet('1.3. PianoBooster', 1),
  bullet('2. Métrica Orientada al Tamaño (Líneas de Código)'),
  bullet('2.1. Metodología', 1),
  bullet('2.2. MuseScore Studio', 1),
  bullet('2.3. Nootka', 1),
  bullet('2.4. PianoBooster', 1),
  bullet('2.5. Cuadro comparativo de tamaño', 1),
  bullet('3. Métrica Orientada a la Función (Puntos de Función)'),
  bullet('3.1. Metodología', 1),
  bullet('3.2. MuseScore Studio', 1),
  bullet('3.3. Nootka', 1),
  bullet('3.4. PianoBooster', 1),
  bullet('3.5. Cuadro comparativo de función', 1),
  bullet('4. Conclusiones'),
);

// Secciones
children.push(...descripcionSection());
const tam = tamanoSection();
children.push(...tam.paragraphs);
const fun = funcionSection();
children.push(...fun.paragraphs);

// Conclusiones
children.push(
  h1('4. Conclusiones'),
  bullet('Las tres aplicaciones analizadas pertenecen al mismo rubro de PianoVision AI (enseñanza y práctica musical) y son de código abierto, lo que permitió obtener su cantidad real de líneas de código desde GitHub. Dos de ellas (MuseScore y Nootka) cuentan además con versiones móviles, igual que nuestro proyecto.'),
  bullet('PianoBooster es la aplicación más liviana y focalizada (30 KLOC, PFA bajo). Representa el referente más directo del núcleo de práctica de PianoVision AI: detección de eventos en tiempo real, evaluación contra una partitura esperada y modos pedagógicos guiados.'),
  bullet('Nootka es el referente más cercano a nuestra funcionalidad estrella: la detección de notas por micrófono. Con un tamaño intermedio (110 KLOC) demuestra que combinar lectura de partituras, reconocimiento de pitch en tiempo real y exámenes correctibles tiene una complejidad funcional considerable (PFA medio).'),
  bullet(`MuseScore Studio es el sistema más grande con diferencia (${fmtMiles(MUSESCORE.kloc)} KLOC), porque el dominio de la notación musical gráfica requiere mucho más código por punto de función (motor de renderizado vectorial, modelo musical e importación/exportación multi-formato). Su métrica de tamaño refleja el mayor esfuerzo, costo y personal de los tres.`),
  bullet('Para el diseño de PianoVision AI conviene combinar las tres referencias: el motor de práctica en tiempo real de PianoBooster, la detección de notas por audio de Nootka, y la dimensión de notación y aprendizaje guiado de MuseScore.'),
  spacer(),
  h2('Referencias'),
  bullet('Pressman, R. S. (2020). Software Engineering: A Practitioner’s Approach (9.ª ed.). McGraw-Hill.'),
  bullet('Boehm, B. W. (1981). Software Engineering Economics. Prentice Hall.'),
  bullet('Albrecht, A. J., & Gaffney, J. E. (1983). Software function, source lines of code, and development effort prediction. IEEE Transactions on Software Engineering, SE-9(6), 639-648.'),
  bullet('IFPUG (2010). Function Point Counting Practices Manual, v4.3.1.'),
  bullet('cloc — Count Lines of Code: https://github.com/AlDanial/cloc'),
  bullet('Repositorios: MuseScore (github.com/musescore/MuseScore) · Nootka (github.com/SeeLook/nootka) · PianoBooster (github.com/captbaritone/pianobooster)'),
  spacer(),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 240 },
    children: [new TextRun({ text: '— Fin de la Primera Parte —', font: FONT, size: 22, italics: true, color: COLOR_MUTED })] })
);

// ===================== Document =====================
const doc = new Document({
  creator: 'PianoVision AI',
  title: 'Primera Parte — Métricas de Software',
  styles: {
    default: { document: { run: { font: FONT, size: 22, color: COLOR_TEXT } } },
    paragraphStyles: [
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 34, bold: true, color: COLOR_HEADING },
        paragraph: { spacing: { before: 360, after: 240 }, outlineLevel: 0 } },
      { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 28, bold: true, color: COLOR_HEADING },
        paragraph: { spacing: { before: 280, after: 180 }, outlineLevel: 1 } },
      { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 24, bold: true, color: COLOR_HEADING },
        paragraph: { spacing: { before: 220, after: 140 }, outlineLevel: 2 } },
    ],
  },
  numbering: {
    config: [{ reference: 'bullets', levels: [
      { level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 360 } } } },
      { level: 1, format: LevelFormat.BULLET, text: '◦', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 1440, hanging: 360 } } } },
    ] }],
  },
  sections: [{
    properties: { page: { size: { width: PAGE_WIDTH, height: PAGE_HEIGHT }, margin: { top: MARGIN, right: MARGIN, bottom: MARGIN, left: MARGIN } } },
    headers: { default: new Header({ children: [new Paragraph({ alignment: AlignmentType.RIGHT,
      children: [new TextRun({ text: 'PianoVision AI — Métricas de Software (Parte 1)', font: FONT, size: 18, color: COLOR_MUTED, italics: true })] })] }) },
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [
      new TextRun({ text: 'Página ', font: FONT, size: 18, color: COLOR_MUTED }),
      new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 18, color: COLOR_MUTED }),
      new TextRun({ text: ' de ', font: FONT, size: 18, color: COLOR_MUTED }),
      new TextRun({ children: [PageNumber.TOTAL_PAGES], font: FONT, size: 18, color: COLOR_MUTED }),
    ] })] }) },
    children,
  }],
});

Packer.toBuffer(doc).then((buffer) => {
  // Carpeta de OneDrive sincronizada (cuenta personal) — al escribir aquí,
  // OneDrive sube el archivo a la nube automáticamente y el equipo lo ve
  // actualizado en Word Online. Es el MISMO archivo siempre (no copias).
  const oneDrivePath = 'C:\\Users\\danie\\OneDrive\\Universidad\\PianoVision-Metricas\\PianoVision-Parte1-Metricas.docx';
  const localPath = path.join(__dirname, 'PianoVision-Parte1-Metricas.docx');

  function tryWrite(p, label) {
    try {
      fs.writeFileSync(p, buffer);
      console.log(`OK ${label}: ${p} (${(buffer.length / 1024).toFixed(1)} KB)`);
    } catch (e) {
      if (e.code === 'EBUSY') {
        console.log(`AVISO ${label}: el archivo está abierto en Word (${p}). Cerralo y reintentá para actualizarlo.`);
      } else {
        console.log(`ERROR ${label}: ${e.message}`);
      }
    }
  }

  tryWrite(oneDrivePath, 'OneDrive');
  tryWrite(localPath, 'local');
});
