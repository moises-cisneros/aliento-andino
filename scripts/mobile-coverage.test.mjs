import { execFileSync } from "node:child_process"
import { mkdtempSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { describe, expect, it } from "vitest"
import { computeCoverage, isGenerated, parseLcov } from "./mobile-coverage.mjs"

const record = (file, found, hit) => `SF:${file}\nLF:${found}\nLH:${hit}\nend_of_record\n`

describe("parseLcov", () => {
  it("reads found and hit lines per file, normalising Windows separators", () => {
    const lcov = record("lib\\a.dart", 10, 4) + record("lib/b.dart", 5, 5)

    expect(parseLcov(lcov)).toEqual([
      { file: "lib/a.dart", found: 10, hit: 4 },
      { file: "lib/b.dart", found: 5, hit: 5 },
    ])
  })
})

describe("isGenerated", () => {
  it("flags build_runner outputs only", () => {
    expect(isGenerated("lib/core/database/app_database.g.dart")).toBe(true)
    expect(isGenerated("lib/models/user.freezed.dart")).toBe(true)
    expect(isGenerated("lib/core/database/app_database.dart")).toBe(false)
  })
})

describe("computeCoverage", () => {
  it("excludes generated files from the figure", () => {
    const lcov =
      record("lib/a.dart", 100, 80) +
      record("lib/a.g.dart", 900, 0) +
      record("lib/b.freezed.dart", 50, 0)

    const { found, hit, percent } = computeCoverage(lcov)

    expect({ found, hit }).toEqual({ found: 100, hit: 80 })
    expect(percent).toBe(80)
  })

  it("reports 0% for an empty report instead of dividing by zero", () => {
    expect(computeCoverage("").percent).toBe(0)
  })
})

describe("CLI gate", () => {
  const run = (lcov, ...args) => {
    const file = join(mkdtempSync(join(tmpdir(), "mobile-cov-")), "lcov.info")
    writeFileSync(file, lcov)
    try {
      const stdout = execFileSync("node", ["scripts/mobile-coverage.mjs", file, ...args], {
        encoding: "utf-8",
        stdio: ["ignore", "pipe", "pipe"],
      })
      return { code: 0, stdout }
    } catch (error) {
      return { code: error.status, stdout: error.stdout, stderr: error.stderr }
    }
  }

  it("passes at or above the minimum", () => {
    expect(run(record("lib/a.dart", 100, 75)).code).toBe(0)
  })

  it("fails below the default 75% minimum", () => {
    const result = run(record("lib/a.dart", 100, 74))

    expect(result.code).toBe(1)
    expect(result.stderr).toContain("below the required minimum of 75%")
  })

  it("honours --min", () => {
    expect(run(record("lib/a.dart", 100, 60), "--min", "50").code).toBe(0)
    expect(run(record("lib/a.dart", 100, 60), "--min", "80").code).toBe(1)
  })

  it("fails on a report with no hand-written lines", () => {
    expect(run(record("lib/a.g.dart", 10, 10)).code).toBe(1)
  })
})
