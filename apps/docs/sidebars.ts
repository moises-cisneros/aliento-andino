import type { SidebarsConfig } from "@docusaurus/plugin-content-docs"

const sidebars: SidebarsConfig = {
  defaultSidebar: [
    {
      type: "category",
      label: "1. Introducción y Visión",
      collapsed: false,
      items: ["index", "introduccion/requisitos"],
    },
    {
      type: "category",
      label: "2. Primeros Pasos",
      collapsed: false,
      items: [
        "primeros-pasos/registro-y-perfil",
        "primeros-pasos/calibracion-soplo",
        "calibracion/soplo-suave",
        "primeros-pasos/calibracion-postura",
      ],
    },
    {
      type: "category",
      label: "3. Instrumentos Andinos",
      collapsed: false,
      items: [
        "instrumentos/quena",
        "quena/embocadura",
        "instrumentos/zampona",
        "zampona/tecnica-ira-arca",
        "instrumentos/tarka",
        "tarka/digitacion",
      ],
    },
    {
      type: "category",
      label: "4. Aprendizaje y Práctica",
      collapsed: false,
      items: ["aprendizaje/lecciones-interactivas", "aprendizaje/tutor-virtual"],
    },
    {
      type: "category",
      label: "5. Comunidad y Progreso",
      collapsed: false,
      items: ["comunidad/ranking-y-logros", "comunidad/duelos-musicales"],
    },
    {
      type: "category",
      label: "6. Panel para Docentes",
      collapsed: false,
      items: ["docentes/panel-gestion"],
    },
    {
      type: "category",
      label: "7. Soporte y Preguntas Frecuentes",
      collapsed: false,
      items: ["soporte/faq"],
    },
    {
      type: "category",
      label: "8. Arquitectura",
      collapsed: false,
      items: ["arquitectura/c4"],
    },
  ],
}

export default sidebars
