// Generador del PERFIL DEL PROYECTO — PianoVision AI
// Mismo estilo visual que generate-docx.js (Parte 1).
// Ejecutar: node generate-perfil-docx.js

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
const CONTENT_WIDTH = PAGE_WIDTH - 2 * MARGIN; // 9026

const FONT = 'Arial';
const COLOR_TEXT = '1F2937';
const COLOR_HEADING = '0E1726';
const COLOR_TABLE_HEADER = 'D7E3FF';
const COLOR_TABLE_BORDER = '94A3B8';
const COLOR_CALLOUT = 'EFF4FF';
const COLOR_MUTED = '6B7280';

const border = { style: BorderStyle.SINGLE, size: 6, color: COLOR_TABLE_BORDER };
const cellBorders = { top: border, bottom: border, left: border, right: border };
const cellMargins = { top: 80, bottom: 80, left: 120, right: 120 };

// ===================== Helpers de párrafo =====================
function p(text, opts = {}) {
  return new Paragraph({
    spacing: { after: 140, ...(opts.spacing || {}) },
    alignment: opts.alignment,
    children: [new TextRun({
      text, font: FONT, size: opts.size || 22, bold: opts.bold,
      italics: opts.italics, color: opts.color || COLOR_TEXT,
    })],
  });
}
function pRuns(runs, opts = {}) {
  return new Paragraph({
    spacing: { after: 140, ...(opts.spacing || {}) },
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
function bullet(text, level = 0) {
  return new Paragraph({
    numbering: { reference: 'bullets', level }, spacing: { after: 80 },
    children: [new TextRun({ text, font: FONT, size: 22, color: COLOR_TEXT })],
  });
}
function bulletRuns(runs, level = 0) {
  return new Paragraph({
    numbering: { reference: 'bullets', level }, spacing: { after: 80 },
    children: runs.map((r) => new TextRun({
      font: FONT, size: r.size || 22, bold: r.bold, italics: r.italics,
      color: r.color || COLOR_TEXT, text: r.text,
    })),
  });
}
function callout(runs) {
  return new Paragraph({
    spacing: { before: 120, after: 160 },
    shading: { fill: COLOR_CALLOUT, type: ShadingType.CLEAR },
    border: {
      left: { style: BorderStyle.SINGLE, size: 24, color: '3B82F6' },
      top: { style: BorderStyle.SINGLE, size: 4, color: COLOR_TABLE_BORDER },
      bottom: { style: BorderStyle.SINGLE, size: 4, color: COLOR_TABLE_BORDER },
      right: { style: BorderStyle.SINGLE, size: 4, color: COLOR_TABLE_BORDER },
    },
    children: runs.map((r) => new TextRun({
      font: FONT, size: r.size || 22, bold: r.bold, italics: r.italics,
      color: r.color || COLOR_TEXT, text: r.text,
    })),
  });
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
function buildTable(headers, rows, columnWidths) {
  const headerRow = new TableRow({
    tableHeader: true,
    children: headers.map((h, i) => textCell(h, {
      width: columnWidths[i], bold: true, shading: COLOR_TABLE_HEADER,
      alignment: AlignmentType.CENTER, size: 20,
    })),
  });
  const bodyRows = rows.map((row) => new TableRow({
    children: row.map((cell, i) => {
      if (typeof cell === 'object' && cell !== null) {
        return textCell(cell.text, {
          width: columnWidths[i], bold: cell.bold, shading: cell.shading,
          alignment: cell.alignment || AlignmentType.LEFT, size: 20,
        });
      }
      return textCell(String(cell), { width: columnWidths[i], alignment: AlignmentType.LEFT, size: 20 });
    }),
  }));
  return new Table({
    width: { size: columnWidths.reduce((a, b) => a + b, 0), type: WidthType.DXA },
    columnWidths, rows: [headerRow, ...bodyRows],
  });
}

// ===================== Contenido =====================
const children = [];

// ---------- Portada ----------
children.push(
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 1200, after: 120 },
    children: [new TextRun({ text: 'INGENIERÍA DE SOFTWARE I (INF422 – SB)', font: FONT, size: 24, bold: true, color: COLOR_HEADING })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 },
    children: [new TextRun({ text: 'Facultad de Ingeniería en Ciencias de la Computación y Telecomunicaciones — UAGRM', font: FONT, size: 20, color: COLOR_MUTED })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 160 },
    children: [new TextRun({ text: 'PERFIL DEL PROYECTO', font: FONT, size: 44, bold: true, color: COLOR_HEADING })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 },
    children: [new TextRun({ text: 'PianoVision AI', font: FONT, size: 30, bold: true, color: COLOR_TEXT })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 },
    children: [new TextRun({ text: 'Plataforma educativa de aprendizaje de piano asistida por inteligencia artificial', font: FONT, size: 22, italics: true, color: COLOR_MUTED })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 },
    children: [new TextRun({ text: 'Grupo 8', font: FONT, size: 22, bold: true, color: COLOR_TEXT })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 },
    children: [new TextRun({ text: 'Integrantes: Lozada Arias Víctor Adolfo (221044914) · Mamani Peña Daniel Joaquín (222157933)', font: FONT, size: 22, color: COLOR_TEXT })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 },
    children: [new TextRun({ text: 'Semestre I – 2026', font: FONT, size: 22, color: COLOR_TEXT })] }),
);

// ---------- Ficha técnica ----------
children.push(h1('Ficha técnica del proyecto', true));
children.push(buildTable(
  ['Campo', 'Detalle'],
  [
    ['Nombre del producto', 'PianoVision AI'],
    ['Tipo de producto', 'Plataforma educativa multiplataforma (app móvil + panel web administrativo + backend)'],
    ['Dominio', 'Educación musical asistida por inteligencia artificial'],
    ['Usuarios objetivo', 'Estudiantes principiantes e intermedios de piano; administradores de contenido'],
    ['Plataformas', 'Android 8.0+ · iOS 13.0+ (móvil) · Navegadores modernos (panel web)'],
    ['Modelo de negocio', 'Freemium (versión gratuita + suscripción premium mensual/anual)'],
    ['Marco de trabajo', 'Scrum (sprints de 3 semanas)'],
  ],
  [2600, 6426]
));

// ---------- 1. Introducción ----------
children.push(h1('1. Introducción'));
children.push(p('El aprendizaje del piano ha dependido históricamente de la presencia de un profesor que observe al estudiante, corrija sus errores y ajuste el ritmo de la enseñanza a su progreso. Este modelo, aunque eficaz, resulta costoso, poco flexible en horarios y geográficamente limitado, lo que deja fuera a una gran cantidad de personas interesadas en aprender música de forma autodidacta.'));
children.push(pRuns([
  { text: 'PianoVision AI', bold: true },
  { text: ' es una plataforma tecnológica orientada al aprendizaje interactivo del piano que utiliza procesamiento digital de audio, visión por computadora e inteligencia artificial para analizar en tiempo real la ejecución musical del usuario. El sistema reconoce las notas que el estudiante toca, evalúa su precisión y su ritmo, y entrega retroalimentación automática personalizada, ofreciendo una experiencia equivalente a la de un profesor virtual de piano disponible en cualquier momento.' },
]));
children.push(pRuns([
  { text: 'El presente documento constituye el ' },
  { text: 'Perfil del Proyecto', bold: true },
  { text: ': define el contexto, los antecedentes, el problema que se busca resolver, la justificación, los objetivos, el alcance y las limitaciones que enmarcan el desarrollo de PianoVision AI. Sirve como punto de partida conceptual sobre el cual se construyen los artefactos de planificación y desarrollo descritos en los sprints posteriores.' },
]));

// ---------- 2. Antecedentes ----------
children.push(h1('2. Antecedentes'));
children.push(p('El interés por digitalizar la enseñanza musical no es nuevo. En la actualidad existen aplicaciones comerciales de aprendizaje de piano ampliamente difundidas —como Simply Piano, flowkey, Yousician o Piano Academy— que han demostrado que el mercado de la educación musical asistida por software es real y está en crecimiento. Sin embargo, estas soluciones presentan limitaciones relevantes: son de código cerrado, operan bajo suscripciones de pago, y varias dependen de la conexión de un teclado MIDI físico o de condiciones controladas para funcionar correctamente.'));
children.push(p('Como parte del análisis previo de este proyecto (ver "Primera Parte — Análisis de Aplicaciones Similares y Estimación"), se estudiaron en profundidad tres referentes de código abierto, maduros y en producción, que cubren las dimensiones funcionales principales del sistema:'));
children.push(buildTable(
  ['Aplicación de referencia', 'Aporte al diseño de PianoVision AI'],
  [
    [{ text: 'MuseScore Studio', bold: true }, 'Notación musical, reproducción asistida y comunidad social educativa'],
    [{ text: 'PianoBooster', bold: true }, 'Práctica guiada y evaluación en tiempo real de la ejecución contra una partitura esperada'],
    [{ text: 'Nootka', bold: true }, 'Detección de notas por micrófono (pitch detection) y exámenes con corrección automática'],
  ],
  [3000, 6026]
));
children.push(pRuns([
  { text: 'De ese estudio comparativo se concluyó que ' },
  { text: 'ninguna herramienta existente combina simultáneamente', bold: true },
  { text: ': (a) la detección de notas por audio sin necesidad de hardware MIDI adicional, (b) el análisis de la ejecución mediante visión por computadora, (c) la retroalimentación generada por inteligencia artificial, y (d) una capa de gamificación y comunidad orientada a la retención del estudiante. Esa combinación define el espacio de oportunidad que PianoVision AI busca ocupar.' },
]));

// ---------- 3. Planteamiento del problema ----------
children.push(h1('3. Planteamiento del problema'));
children.push(p('El aprendizaje autodidacta del piano enfrenta un obstáculo central: la ausencia de retroalimentación inmediata y confiable. Cuando un estudiante practica solo, no dispone de un mecanismo que le indique en el momento si está tocando las notas correctas, si respeta el tempo de la pieza o si su técnica es adecuada, por lo que tiende a consolidar errores difíciles de corregir más adelante.'));
children.push(p('Las alternativas digitales disponibles atenúan parcialmente este problema, pero introducen barreras propias: requieren la compra de un teclado MIDI, funcionan bajo modelos de pago poco accesibles, son de código cerrado —lo que impide adaptarlas a un contexto educativo específico— y, en general, no integran en una sola solución el análisis de audio, el análisis visual de la ejecución y la retroalimentación inteligente.'));
children.push(callout([
  { text: 'Formulación del problema: ', bold: true },
  { text: '¿Cómo proporcionar a un estudiante principiante o intermedio de piano una evaluación automática, inmediata y personalizada de su ejecución musical —sin necesidad de un profesor presencial ni de hardware especializado— utilizando únicamente la cámara y el micrófono de un dispositivo móvil convencional?', italics: true },
]));

// ---------- 4. Justificación ----------
children.push(h1('4. Justificación'));
children.push(p('El desarrollo de PianoVision AI se justifica desde tres perspectivas:'));
children.push(bulletRuns([
  { text: 'Social y educativa. ', bold: true },
  { text: 'Democratiza el acceso al aprendizaje del piano al eliminar la dependencia de un profesor presencial en las etapas inicial e intermedia, reduciendo barreras económicas y geográficas. El estudiante practica de forma autónoma mientras recibe evaluación inmediata de su interpretación.' },
]));
children.push(bulletRuns([
  { text: 'Tecnológica. ', bold: true },
  { text: 'Aprovecha la disponibilidad masiva de cámaras y micrófonos en los teléfonos inteligentes para reemplazar el hardware MIDI especializado. La detección de notas mediante procesamiento de audio en tiempo real (algoritmo YIN para monofonía y FFT para detección de acordes), el análisis de digitación por visión computacional y la retroalimentación generada por modelos de inteligencia artificial (Gemini, sobre Vertex AI) hacen posible una experiencia de tutoría virtual sobre dispositivos de uso cotidiano.' },
]));
children.push(bulletRuns([
  { text: 'Económica. ', bold: true },
  { text: 'El modelo freemium permite un acceso gratuito a contenido básico que facilita la adopción, a la vez que sostiene la plataforma mediante una suscripción premium con contenido avanzado, análisis detallado del desempeño e historial de progreso.' },
]));
children.push(pRuns([
  { text: 'Adicionalmente, en el plano ' },
  { text: 'académico', bold: true },
  { text: ', el proyecto constituye un caso integral de aplicación de la Ingeniería de Software: combina el desarrollo móvil (Flutter), web (Angular) y de servicios backend (FastAPI), bajo el marco de trabajo Scrum, integración continua y prácticas de calidad como pruebas automatizadas, control de versiones y arquitectura limpia.' },
]));

// ---------- 5. Objetivos ----------
children.push(h1('5. Objetivos'));
children.push(h2('5.1. Objetivo general'));
children.push(p('Desarrollar un sistema de software educativo multiplataforma para la enseñanza integral del piano, que combine una aplicación móvil (Android/iOS) construida con Flutter y una plataforma web administrativa construida con Angular y FastAPI, capaz de analizar la ejecución musical del usuario en tiempo real mediante procesamiento de audio, visión por computadora e inteligencia artificial, y de entregar una experiencia de aprendizaje personalizada, adaptativa e interactiva que abarque desde el nivel inicial hasta el intermedio.'));
children.push(h2('5.2. Objetivos específicos'));
[
  'Implementar un sistema de aprendizaje adaptativo basado en una evaluación diagnóstica inicial del nivel del usuario.',
  'Desarrollar un motor de notación musical capaz de interpretar y renderizar archivos MusicXML y MIDI, sincronizándolos con la ejecución del usuario.',
  'Integrar un sistema de análisis de audio en tiempo real para la identificación de notas, la evaluación de la precisión y la detección del ritmo (tempo).',
  'Incorporar visión por computadora para el análisis de la postura y la digitación de las manos sobre el teclado.',
  'Generar retroalimentación automática y personalizada del desempeño mediante inteligencia artificial.',
  'Incorporar un sistema de gamificación (puntos, niveles, rachas, logros y rankings) para mejorar la retención y la motivación del usuario.',
  'Diseñar un sistema híbrido que combine contenido disponible sin conexión (offline) con las funcionalidades avanzadas de IA en línea (online).',
  'Desarrollar una plataforma web administrativa para la gestión de usuarios, contenidos, moderación y la generación de reportes analíticos.',
].forEach((t) => children.push(bullet(t)));

// ---------- 6. Alcance ----------
children.push(h1('6. Alcance'));
children.push(p('El proyecto contempla el desarrollo de los siguientes componentes y funcionalidades:'));
children.push(h2('Componentes del sistema'));
[
  ['Aplicación móvil (Flutter): ', 'cliente principal para el estudiante, disponible en Android e iOS.'],
  ['Plataforma web administrativa (Angular): ', 'panel para administradores de contenido y moderación.'],
  ['Backend de servicios (FastAPI + PostgreSQL): ', 'API REST, lógica de negocio, autenticación y persistencia.'],
  ['Servicios de IA y procesamiento: ', 'análisis de audio, visión por computadora y generación de retroalimentación.'],
].forEach(([b, t]) => children.push(bulletRuns([{ text: b, bold: true }, { text: t }])));
children.push(h2('Funcionalidades incluidas'));
[
  'Registro, autenticación segura (JWT) y gestión de perfiles de usuario.',
  'Evaluación diagnóstica inicial y generación de rutas de aprendizaje personalizadas.',
  'Biblioteca de lecciones, ejercicios y canciones organizadas por nivel de dificultad.',
  'Guía visual de ejecución previa a la práctica (notas a presionar, demostración paso a paso).',
  'Detección de notas por audio en tiempo real y evaluación de precisión y tempo.',
  'Análisis de la ejecución mediante cámara (postura y digitación).',
  'Retroalimentación automática del desempeño con recomendaciones de mejora.',
  'Gamificación: puntos, niveles, rachas, logros y ranking global.',
  'Funcionalidad offline para contenido básico y descarga de lecciones.',
  'Panel administrativo: gestión de usuarios, contenidos, moderación y reportes analíticos exportables.',
].forEach((t) => children.push(bullet(t)));

// ---------- 7. Limitaciones y supuestos ----------
children.push(h1('7. Limitaciones y supuestos'));
children.push(h2('Limitaciones'));
[
  ['', 'El sistema está orientado a estudiantes de nivel inicial e intermedio; no abarca el repertorio ni la evaluación de nivel profesional o de conservatorio.'],
  ['', 'Las funcionalidades avanzadas de inteligencia artificial requieren conexión a internet; en modo offline solo está disponible el contenido básico previamente descargado.'],
  ['', 'La precisión de la detección de notas y de la digitación depende de las condiciones del entorno (iluminación, ángulo de la cámara, ruido acústico y calidad del micrófono).'],
  ['', 'El análisis polifónico (acordes) se centra en acordes simples; la transcripción polifónica compleja queda fuera del alcance de esta versión.'],
].forEach(([, t]) => children.push(bullet(t)));
children.push(h2('Supuestos'));
[
  'El usuario dispone de un dispositivo móvil con cámara (mínimo 720p) y micrófono funcionales, compatible con Android 8.0+ o iOS 13.0+.',
  'El usuario cuenta con un piano acústico o teclado electrónico físico sobre el cual practicar frente a la cámara.',
  'Para las funciones en línea, el usuario dispone de una conexión a internet estable.',
].forEach((t) => children.push(bullet(t)));

// ---------- 8. Marco conceptual ----------
children.push(h1('8. Marco conceptual'));
children.push(p('A continuación se definen los conceptos clave que sustentan el proyecto:'));
[
  ['DSP (Procesamiento Digital de Señales): ', 'conjunto de técnicas para analizar señales de audio; en PianoVision AI se emplea para detectar la frecuencia fundamental de las notas tocadas.'],
  ['Detección de pitch (YIN / FFT): ', 'algoritmos que estiman la altura tonal de un sonido. YIN se usa para sonidos monofónicos (una nota a la vez) y la FFT (Transformada Rápida de Fourier) para identificar componentes de acordes.'],
  ['Visión por computadora: ', 'análisis automático de imágenes de la cámara para localizar el teclado y la posición de los dedos del usuario.'],
  ['MusicXML / MIDI: ', 'formatos estándar de representación de notación y eventos musicales que el sistema interpreta y sincroniza con la práctica.'],
  ['Inteligencia Artificial generativa: ', 'modelos (Gemini sobre Vertex AI) que producen retroalimentación textual personalizada a partir del desempeño del usuario.'],
  ['Gamificación: ', 'aplicación de mecánicas de juego (puntos, niveles, rachas, logros, rankings) para incrementar la motivación y la retención.'],
  ['JWT (JSON Web Token): ', 'mecanismo de autenticación basado en tokens firmados utilizado para proteger el acceso a los servicios del sistema.'],
  ['Scrum: ', 'marco de trabajo ágil bajo el cual se organiza el desarrollo del proyecto en sprints iterativos e incrementales.'],
].forEach(([b, t]) => children.push(bulletRuns([{ text: b, bold: true }, { text: t }])));

children.push(spacer());
children.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 240 },
  children: [new TextRun({ text: '— Fin del Perfil del Proyecto —', font: FONT, size: 22, italics: true, color: COLOR_MUTED })] }));

// ===================== Document =====================
const doc = new Document({
  creator: 'PianoVision AI',
  title: 'Perfil del Proyecto — PianoVision AI',
  styles: {
    default: { document: { run: { font: FONT, size: 22, color: COLOR_TEXT } } },
    paragraphStyles: [
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 34, bold: true, color: COLOR_HEADING },
        paragraph: { spacing: { before: 360, after: 240 }, outlineLevel: 0 } },
      { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 28, bold: true, color: COLOR_HEADING },
        paragraph: { spacing: { before: 280, after: 180 }, outlineLevel: 1 } },
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
      children: [new TextRun({ text: 'PianoVision AI — Perfil del Proyecto', font: FONT, size: 18, color: COLOR_MUTED, italics: true })] })] }) },
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
  const localPath = path.join(__dirname, 'PianoVision-Perfil-Proyecto.docx');
  const oneDriveDir = 'C:\\Users\\danie\\OneDrive\\Universidad';
  const oneDrivePath = path.join(oneDriveDir, 'PianoVision-Perfil-Proyecto.docx');

  function tryWrite(p, label) {
    try {
      fs.writeFileSync(p, buffer);
      console.log(`OK ${label}: ${p} (${(buffer.length / 1024).toFixed(1)} KB)`);
    } catch (e) {
      if (e.code === 'EBUSY') console.log(`AVISO ${label}: el archivo está abierto en Word (${p}). Cerralo y reintentá.`);
      else console.log(`AVISO ${label}: no se pudo escribir (${e.code || e.message}).`);
    }
  }

  tryWrite(localPath, 'local');
  if (fs.existsSync(oneDriveDir)) tryWrite(oneDrivePath, 'OneDrive');
});
