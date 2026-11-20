import { describe, expect, it, vi } from "vitest"
import { parseTargets, ping, pingAll } from "./index"

describe("parseTargets", () => {
  it("separa por comas, recorta espacios y descarta vacios/invalidos", () => {
    expect(parseTargets(" https://a.onrender.com/health, ,nope,ftp://x,http://b/health ")).toEqual([
      "https://a.onrender.com/health",
      "http://b/health",
    ])
  })
  it("devuelve lista vacia con undefined o cadena vacia", () => {
    expect(parseTargets(undefined)).toEqual([])
    expect(parseTargets("")).toEqual([])
  })
})

describe("ping", () => {
  it("envia User-Agent y reporta status", async () => {
    const f = vi.fn(async () => new Response("ok", { status: 200 }))
    const r = await ping("https://a/health", f as unknown as typeof fetch)
    expect(r).toMatchObject({ url: "https://a/health", ok: true, status: 200 })
    const init = (f.mock.calls[0] as unknown as [string, RequestInit])[1]
    expect((init.headers as Record<string, string>)["User-Agent"]).toBe("aliento-keepalive")
    expect(init.signal).toBeInstanceOf(AbortSignal)
  })
  it("captura errores de red sin lanzar", async () => {
    const f = vi.fn(async () => {
      throw new Error("boom")
    })
    const r = await ping("https://a", f as unknown as typeof fetch)
    expect(r).toMatchObject({ ok: false, status: null, error: "boom" })
  })
  it("marca ok=false con status 5xx", async () => {
    const f = vi.fn(async () => new Response("", { status: 503 }))
    expect((await ping("https://a", f as unknown as typeof fetch)).ok).toBe(false)
  })
})

describe("pingAll", () => {
  it("consulta todos los targets", async () => {
    const f = vi.fn(async () => new Response("", { status: 200 }))
    const rs = await pingAll(["https://a", "https://b"], f as unknown as typeof fetch)
    expect(rs).toHaveLength(2)
    expect(f).toHaveBeenCalledTimes(2)
  })
})
