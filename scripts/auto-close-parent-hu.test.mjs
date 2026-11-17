import { describe, expect, it } from "vitest"
import { findCompletedParents, parseSubIssueRefs } from "./auto-close-parent-hu.mjs"

const hu = (number, body, extra = {}) => ({
  number,
  title: `[HU-${number}] story`,
  body,
  state: "OPEN",
  labels: [{ name: "type:feature" }],
  ...extra,
})

const sub = (number, state) => ({
  number,
  title: `[SUB-${number}] task`,
  body: "",
  state,
  labels: [],
})

describe("parseSubIssueRefs", () => {
  it("reads the sub-issues from the task list, checked or not", () => {
    const body = ["- [ ] #13 — [SUB-02-A] wizard", "- [x] #14 — [SUB-02-B] threshold"].join("\n")
    expect(parseSubIssueRefs(body)).toEqual([13, 14])
  })

  it("ignores checkboxes that are not sub-issue references", () => {
    const body = [
      "- [ ] #13 — [SUB-02-A] wizard",
      "- [ ] Retroalimentación cromática en pantalla",
      "- [ ] Mentions #99 in the middle of a sentence",
    ].join("\n")
    expect(parseSubIssueRefs(body)).toEqual([13])
  })

  it("returns an empty list for an empty or missing body", () => {
    expect(parseSubIssueRefs("")).toEqual([])
    expect(parseSubIssueRefs(null)).toEqual([])
  })

  it("does not repeat a reference", () => {
    expect(parseSubIssueRefs("- [ ] #13 — a\n- [ ] #13 — b")).toEqual([13])
  })
})

describe("findCompletedParents", () => {
  it("closes a HU whose sub-issues are all closed, even with unticked boxes", () => {
    const parent = hu(12, "- [ ] #13 — a\n- [ ] #14 — b\n- [ ] Acceptance criterion")
    const result = findCompletedParents([parent, sub(13, "CLOSED"), sub(14, "CLOSED")])
    expect(result.map((i) => i.number)).toEqual([12])
  })

  it("keeps a HU open while any sub-issue is still open", () => {
    const parent = hu(12, "- [x] #13 — a\n- [x] #14 — b")
    expect(findCompletedParents([parent, sub(13, "CLOSED"), sub(14, "OPEN")])).toEqual([])
  })

  it("never closes a HU without sub-issue references", () => {
    expect(findCompletedParents([hu(12, "- [x] done\n- [x] also done")])).toEqual([])
  })

  it("keeps a HU open when a referenced sub-issue cannot be found", () => {
    expect(findCompletedParents([hu(12, "- [ ] #13 — a")])).toEqual([])
  })

  it("only looks at open feature issues", () => {
    const closedHu = hu(12, "- [ ] #13 — a", { state: "CLOSED" })
    const plain = hu(20, "- [ ] #13 — a", { title: "chore: tidy", labels: [] })
    expect(findCompletedParents([closedHu, plain, sub(13, "CLOSED")])).toEqual([])
  })

  it("recognises a HU by its title when the label is missing", () => {
    const parent = hu(12, "- [ ] #13 — a", { labels: [] })
    expect(findCompletedParents([parent, sub(13, "CLOSED")]).map((i) => i.number)).toEqual([12])
  })
})
