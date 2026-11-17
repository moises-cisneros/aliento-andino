#!/usr/bin/env node
import { execSync } from "node:child_process"
import { pathToFileURL } from "node:url"

/**
 * User story (HU) lifecycle automation.
 *
 * A parent HU lists its sub-issues as a task list ("- [ ] #13 — [SUB-02-A] ..."). GitHub never
 * ticks those boxes in the issue body, so the real signal is the state of each referenced
 * sub-issue: when every one of them is closed, the HU is done and gets closed.
 *
 * Usage:
 *   node scripts/auto-close-parent-hu.mjs             close every completed HU
 *   node scripts/auto-close-parent-hu.mjs --dry-run   only report what would be closed
 */

// A sub-issue reference is a task-list item that starts with an issue number.
const SUB_ISSUE_LINE = /^\s*- \[[ xX]\] #(\d+)\b/gm

export function parseSubIssueRefs(body) {
  const refs = new Set()
  for (const match of (body ?? "").matchAll(SUB_ISSUE_LINE)) {
    refs.add(Number(match[1]))
  }
  return [...refs]
}

function isUserStory(issue) {
  return (
    issue.labels?.some((l) => l.name === "type:feature") || /^\[?HU-\d+\]?/i.test(issue.title ?? "")
  )
}

/**
 * Open HUs whose sub-issues are all closed. A HU with no sub-issue references, or with a
 * reference that cannot be found, is never closed.
 */
export function findCompletedParents(issues) {
  const stateByNumber = new Map(issues.map((i) => [i.number, i.state]))

  return issues.filter((issue) => {
    if (issue.state !== "OPEN" || !isUserStory(issue)) return false
    const refs = parseSubIssueRefs(issue.body)
    return refs.length > 0 && refs.every((n) => stateByNumber.get(n) === "CLOSED")
  })
}

function listIssues() {
  const json = execSync(
    "gh issue list --state all --limit 500 --json number,title,body,labels,state",
    { encoding: "utf-8", stdio: ["inherit", "pipe", "inherit"] }
  )
  return JSON.parse(json || "[]")
}

function checkAndCloseParentHUs({ dryRun }) {
  console.log("Checking open user stories (HU) against the state of their sub-issues...")

  let issues
  try {
    issues = listIssues()
  } catch (error) {
    console.error("Could not list issues with the gh CLI:", error.message)
    process.exit(1)
  }

  const completed = findCompletedParents(issues)
  let closedCount = 0

  for (const issue of completed) {
    const refs = parseSubIssueRefs(issue.body)
    console.log(
      `HU #${issue.number} ("${issue.title}"): sub-issues ${refs.map((n) => `#${n}`).join(", ")} are closed.`
    )

    if (dryRun) continue

    const comment =
      "All sub-issues linked to this user story are resolved and closed. " +
      "Closing the parent issue automatically."
    try {
      execSync(`gh issue close ${issue.number} --reason completed --comment "${comment}"`, {
        stdio: "inherit",
      })
      closedCount++
    } catch (error) {
      console.error(`Could not close issue #${issue.number}:`, error.message)
    }
  }

  const verb = dryRun ? "would close" : "closed"
  console.log(`Done. HUs ${verb}: ${dryRun ? completed.length : closedCount}.`)
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  checkAndCloseParentHUs({ dryRun: process.argv.includes("--dry-run") })
}
