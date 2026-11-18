#!/usr/bin/env node
// Guard for PR closing keywords (issue #122).
//  (a) FAIL when a `<type>/<n>-<desc>` branch PR body lacks `Closes #<n>`.
//  (b) WARN when the PR closes issues whose `area:*` label is not among the
//      areas of the files the PR touches.
// All PR text arrives through env vars, never through shell interpolation.

import { pathToFileURL } from "node:url"

const AREAS = ["backend", "mobile", "web", "ml", "infra", "docs"]

/** Issue number from a `<type>/<number>-<desc>` branch, or null (e.g. `docs/xyz`). */
export function issueFromBranch(branch) {
  const match = /^[a-z]+\/(\d+)-/i.exec(branch ?? "")
  return match ? Number(match[1]) : null
}

/** Issue numbers referenced with GitHub closing keywords in the body. */
export function closedIssues(body) {
  const re = /\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s*:?\s+#(\d+)/gi
  const found = new Set()
  for (const m of String(body ?? "").matchAll(re)) found.add(Number(m[1]))
  return [...found]
}

/** Area (one of AREAS) that owns a changed file path. */
export function areaOfFile(path) {
  if (path.startsWith("apps/docs/") || path.startsWith("docs/")) return "docs"
  const app = /^apps\/(backend|mobile|web|ml)\//.exec(path)
  if (app) return app[1]
  if (/^(infra|\.github|scripts|\.husky)\//.test(path)) return "infra"
  return null
}

export function areasOfFiles(paths) {
  return new Set(paths.map(areaOfFile).filter(Boolean))
}

/** Area names from `area:*` labels (strings or `{name}` objects). */
export function areaLabels(labels) {
  return (labels ?? [])
    .map((l) => (typeof l === "string" ? l : l.name))
    .filter((n) => typeof n === "string" && n.startsWith("area:"))
    .map((n) => n.slice(5))
    .filter((a) => AREAS.includes(a))
}

/**
 * @param {{branch: string, body: string, files: string[], labelsByIssue: Record<number, unknown[]>}} input
 * @returns {{skipped: boolean, errors: string[], warnings: string[]}}
 */
export function evaluate({ branch, body, files = [], labelsByIssue = {} }) {
  const expected = issueFromBranch(branch)
  if (expected === null) return { skipped: true, errors: [], warnings: [] }

  const closes = closedIssues(body)
  const errors = []
  const warnings = []
  if (!closes.includes(expected)) {
    errors.push(
      `Branch "${branch}" refers to #${expected} but the PR body lacks "Closes #${expected}".`
    )
  }
  const touched = areasOfFiles(files)
  for (const n of closes) {
    const areas = areaLabels(labelsByIssue[n])
    if (areas.length && !areas.some((a) => touched.has(a))) {
      warnings.push(
        `#${n} is labelled area:${areas.join(",")} but the PR only touches [${[...touched].join(", ") || "none"}]; make sure it should really be closed.`
      )
    }
  }
  return { skipped: false, errors, warnings }
}

async function gh(path) {
  const res = await fetch(`https://api.github.com/${path}`, {
    headers: {
      Authorization: `Bearer ${process.env.GH_TOKEN}`,
      Accept: "application/vnd.github+json",
    },
  })
  if (!res.ok) throw new Error(`GitHub API ${path}: ${res.status}`)
  return res.json()
}

async function main() {
  const { HEAD_REF, PR_BODY, PR_NUMBER, GITHUB_REPOSITORY } = process.env
  const branch = HEAD_REF ?? ""
  if (issueFromBranch(branch) === null) {
    console.log(`Branch "${branch}" has no issue number; closing guard skipped.`)
    return
  }
  const repo = GITHUB_REPOSITORY
  const files = []
  for (let page = 1; ; page++) {
    const batch = await gh(`repos/${repo}/pulls/${PR_NUMBER}/files?per_page=100&page=${page}`)
    files.push(...batch.map((f) => f.filename))
    if (batch.length < 100) break
  }
  const labelsByIssue = {}
  for (const n of closedIssues(PR_BODY)) {
    try {
      labelsByIssue[n] = (await gh(`repos/${repo}/issues/${n}`)).labels
    } catch (err) {
      console.log(`::warning::Could not read labels of #${n}: ${err.message}`)
    }
  }
  const { errors, warnings } = evaluate({ branch, body: PR_BODY, files, labelsByIssue })
  for (const w of warnings) console.log(`::warning::${w}`)
  for (const e of errors) console.log(`::error::${e}`)
  if (errors.length) process.exit(1)
  console.log("PR closing keywords look consistent.")
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((err) => {
    console.error(err)
    process.exit(1)
  })
}
