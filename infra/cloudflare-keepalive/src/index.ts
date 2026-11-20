export interface Env {
  TARGETS: string
}

export interface PingResult {
  url: string
  ok: boolean
  status: number | null
  ms: number
  error?: string
  at: string
}

const TIMEOUT_MS = 10_000
const USER_AGENT = "aliento-keepalive"

/** Convierte "a, b,,c" en URLs http(s) validas; descarta entradas vacias o invalidas. */
export function parseTargets(raw: string | undefined): string[] {
  return (raw ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter((s) => {
      if (!s) return false
      try {
        const { protocol } = new URL(s)
        return protocol === "http:" || protocol === "https:"
      } catch {
        return false
      }
    })
}

export async function ping(url: string, fetcher: typeof fetch = fetch): Promise<PingResult> {
  const start = Date.now()
  const at = new Date(start).toISOString()
  try {
    const res = await fetcher(url, {
      method: "GET",
      headers: { "User-Agent": USER_AGENT },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    })
    // No necesitamos el cuerpo; liberarlo evita retener la conexion.
    await res.body?.cancel()
    return { url, ok: res.ok, status: res.status, ms: Date.now() - start, at }
  } catch (err) {
    return {
      url,
      ok: false,
      status: null,
      ms: Date.now() - start,
      error: err instanceof Error ? err.message : String(err),
      at,
    }
  }
}

export async function pingAll(
  targets: string[],
  fetcher: typeof fetch = fetch
): Promise<PingResult[]> {
  return Promise.all(targets.map((t) => ping(t, fetcher)))
}

// Ultimo resultado por isolate: solo ayuda a la comprobacion manual; no es estado critico.
let lastResults: PingResult[] = []

export default {
  async scheduled(_event, env, ctx): Promise<void> {
    const targets = parseTargets(env.TARGETS)
    if (targets.length === 0) {
      console.log(JSON.stringify({ msg: "keepalive: sin TARGETS configurados" }))
      return
    }
    ctx.waitUntil(
      pingAll(targets).then((results) => {
        lastResults = results
        for (const r of results) console.log(JSON.stringify(r))
      })
    )
  },

  async fetch(_request, env): Promise<Response> {
    const targets = parseTargets(env.TARGETS)
    // Si aun no hubo ejecucion de cron en este isolate, hacer un ping bajo demanda.
    const results = lastResults.length > 0 ? lastResults : await pingAll(targets)
    return Response.json({ targets, results })
  },
} satisfies ExportedHandler<Env>
