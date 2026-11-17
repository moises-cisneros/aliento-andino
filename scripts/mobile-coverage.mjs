#!/usr/bin/env node
import { readFileSync } from "node:fs"
import { pathToFileURL } from "node:url"

/**
 * Official line-coverage figure for apps/mobile.
 *
 * Generated sources (`*.g.dart`, `*.freezed.dart`) are excluded from the computation: they are
 * produced by build_runner, contain no hand-written logic, and would only dilute the metric.
 *
 * Usage:
 *   node scripts/mobile-coverage.mjs [lcov.info] [--min 75]
 *
 * Exits with code 1 when the coverage is below --min (default 75).
 */

const GENERATED = /\.(g|freezed)\.dart$/
const DEFAULT_MIN = 75

export function isGenerated(path) {
  return GENERATED.test(path)
}

/** Parse an lcov report into `{ file, found, hit }` records. */
export function parseLcov(content) {
  const records = []
  for (const block of content.split("end_of_record")) {
    const file = /^SF:(.+)$/m.exec(block)?.[1]?.trim()
    if (!file) continue
    records.push({
      file: file.replaceAll("\\", "/"),
      found: Number(/^LF:(\d+)$/m.exec(block)?.[1] ?? 0),
      hit: Number(/^LH:(\d+)$/m.exec(block)?.[1] ?? 0),
    })
  }
  return records
}

/** Line coverage over hand-written sources only. */
export function computeCoverage(content) {
  const records = parseLcov(content).filter((r) => !isGenerated(r.file))
  const found = records.reduce((sum, r) => sum + r.found, 0)
  const hit = records.reduce((sum, r) => sum + r.hit, 0)
  return { found, hit, percent: found === 0 ? 0 : (hit / found) * 100 }
}

function main(argv) {
  const minIndex = argv.indexOf("--min")
  const min = minIndex === -1 ? DEFAULT_MIN : Number(argv[minIndex + 1])
  const minValueIndex = minIndex === -1 ? -1 : minIndex + 1
  const path =
    argv.find((a, i) => !a.startsWith("--") && i !== minValueIndex) ??
    "apps/mobile/coverage/lcov.info"

  if (Number.isNaN(min)) {
    console.error("--min must be a number")
    process.exit(2)
  }

  let content
  try {
    content = readFileSync(path, "utf-8")
  } catch (error) {
    console.error(`Could not read ${path}: ${error.message}`)
    process.exit(2)
  }

  const { found, hit, percent } = computeCoverage(content)
  console.log(
    `Mobile line coverage (generated files excluded): ${percent.toFixed(1)}% (${hit}/${found})`
  )
  if (found === 0 || percent < min) {
    console.error(`Coverage is below the required minimum of ${min}%.`)
    process.exit(1)
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main(process.argv.slice(2))
}
