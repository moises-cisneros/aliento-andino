import { describe, expect, it } from "vitest"
import {
  areaLabels,
  areaOfFile,
  closedIssues,
  evaluate,
  issueFromBranch,
} from "./pr-closes-guard.mjs"

describe("issueFromBranch", () => {
  it("reads the number from <type>/<n>-<desc>", () => {
    expect(issueFromBranch("feat/43-bandeja")).toBe(43)
    expect(issueFromBranch("chore/122-guarda")).toBe(122)
  })
  it("returns null without a number", () => {
    expect(issueFromBranch("docs/xyz")).toBe(null)
    expect(issueFromBranch("main")).toBe(null)
  })
})

describe("closedIssues", () => {
  it("collects closing keywords, ignores plain references", () => {
    expect(closedIssues("Closes #43\nfixes #7 and see #9")).toEqual([43, 7])
  })
})

describe("areaOfFile", () => {
  it("maps paths to areas", () => {
    expect(areaOfFile("apps/web/src/a.ts")).toBe("web")
    expect(areaOfFile("apps/docs/x.md")).toBe("docs")
    expect(areaOfFile("scripts/a.mjs")).toBe("infra")
    expect(areaOfFile("README.md")).toBe(null)
  })
})

describe("areaLabels", () => {
  it("extracts area labels only", () => {
    expect(areaLabels([{ name: "area:web" }, "type:chore", "area:bogus"])).toEqual(["web"])
  })
})

describe("evaluate", () => {
  const labels = { 43: [{ name: "area:web" }], 41: [{ name: "area:mobile" }] }
  it("passes a valid PR", () => {
    const r = evaluate({
      branch: "feat/43-x",
      body: "Closes #43",
      files: ["apps/web/a.ts"],
      labelsByIssue: labels,
    })
    expect(r).toEqual({ skipped: false, errors: [], warnings: [] })
  })
  it("fails when Closes is missing", () => {
    const r = evaluate({
      branch: "feat/43-x",
      body: "no keyword",
      files: ["apps/web/a.ts"],
      labelsByIssue: labels,
    })
    expect(r.errors.length).toBe(1)
    expect(r.errors[0]).toMatch(/Closes #43/)
  })
  it("warns when closing an issue of an untouched area", () => {
    const r = evaluate({
      branch: "feat/43-x",
      body: "Closes #43\nCloses #41",
      files: ["apps/web/a.ts"],
      labelsByIssue: labels,
    })
    expect(r.errors).toEqual([])
    expect(r.warnings.length).toBe(1)
    expect(r.warnings[0]).toMatch(/#41/)
  })
  it("skips branches without an issue number", () => {
    const r = evaluate({ branch: "docs/xyz", body: "", files: [], labelsByIssue: {} })
    expect(r.skipped).toBe(true)
    expect(r.errors).toEqual([])
  })
})
