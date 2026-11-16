import { execSync } from "node:child_process"

/**
 * Script de automatización de ciclo de vida de Historias de Usuario (HUs).
 * Verifica si todas las subtareas/sub-issues de una HU madre están completadas (checkboxes marcados).
 * Si no quedan tareas pendientes (- [ ]), cierra la issue madre automáticamente.
 */
function checkAndCloseParentHUs() {
  console.log("🔍 Verificando Historias de Usuario (HUs) abiertas en el repositorio...")

  let issuesJson = ""
  try {
    issuesJson = execSync(
      "gh issue list --state open --limit 100 --json number,title,body,labels",
      {
        encoding: "utf-8",
        stdio: ["inherit", "pipe", "inherit"],
      }
    )
  } catch (error) {
    console.error("❌ Error al consultar issues con gh CLI:", error.message)
    process.exit(1)
  }

  const issues = JSON.parse(issuesJson || "[]")
  let closedCount = 0

  for (const issue of issues) {
    const isFeature =
      issue.labels?.some((l) => l.name === "type:feature") ||
      /^HU-\d+/i.test(issue.title) ||
      /^\[HU-\d+\]/i.test(issue.title)

    if (!isFeature) continue

    const body = issue.body || ""
    const uncheckedBoxes = body.match(/- \[\s\]/g) || []
    const checkedBoxes = body.match(/- \[[xX]\]/g) || []

    // Si tiene checkboxes definidos y ya no queda NINGUNO sin marcar:
    if (checkedBoxes.length > 0 && uncheckedBoxes.length === 0) {
      console.log(
        `✅ HU Madre #${issue.number} ("${issue.title}") tiene todas sus tareas completadas (${checkedBoxes.length}/${checkedBoxes.length}).`
      )
      console.log(`🔒 Procediendo al cierre automático de la issue #${issue.number}...`)

      const comment =
        `🎉 **Historia de Usuario Completada**\n\n` +
        `Todas las subtareas y sub-issues vinculadas a esta Historia de Usuario han sido resueltas y cerradas mediante sus respectivos Pull Requests.\n\n` +
        `Cerrando automáticamente la issue madre.`

      try {
        execSync(`gh issue close ${issue.number} --comment "${comment}"`, {
          stdio: "inherit",
        })
        closedCount++
      } catch (err) {
        console.error(`⚠️ No se pudo cerrar la issue #${issue.number}:`, err.message)
      }
    }
  }

  console.log(`✨ Verificación completada. HUs madres cerradas en esta ejecución: ${closedCount}.`)
}

checkAndCloseParentHUs()
