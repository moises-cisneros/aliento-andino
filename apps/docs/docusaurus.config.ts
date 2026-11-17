import { themes as prismThemes } from "prism-react-renderer"
import type { Config } from "@docusaurus/types"
import type * as Preset from "@docusaurus/preset-classic"

const config: Config = {
  title: "Aliento Andino",
  tagline: "Tutor Virtual Interactivo y Red Social de Aerófonos Andinos",
  favicon: "img/favicon.ico",

  url: process.env.DOCS_URL || "https://moises-cisneros.github.io",
  baseUrl: process.env.DOCS_BASE_URL || "/aliento-andino/",

  organizationName: "moises-cisneros",
  projectName: "aliento-andino",
  trailingSlash: false,

  onBrokenLinks: "throw",
  onBrokenMarkdownLinks: "throw",

  i18n: {
    defaultLocale: "es",
    locales: ["es"],
  },

  presets: [
    [
      "classic",
      {
        docs: {
          sidebarPath: "./sidebars.ts",
          routeBasePath: "/",
        },
        blog: false,
        theme: {
          customCss: "./src/css/custom.css",
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    navbar: {
      title: "Aliento Andino Docs",
      items: [
        {
          type: "docSidebar",
          sidebarId: "defaultSidebar",
          position: "left",
          label: "Guía de Usuario y Arquitectura",
        },
        {
          href: "https://github.com/moises-cisneros/aliento-andino",
          label: "GitHub",
          position: "right",
        },
      ],
    },
    footer: {
      style: "dark",
      copyright: `Copyright © ${new Date().getFullYear()} Moises Cisneros — Aliento Andino.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ["bash", "json", "python", "dart"],
    },
  } satisfies Preset.ThemeConfig,
}

export default config
