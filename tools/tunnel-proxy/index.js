const localtunnel = require("localtunnel")
const axios = require("axios")
const winston = require("winston")
const config = require("./config")

// Configurar logger
const logger = winston.createLogger({
  level: config.logLevel,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.printf(({ timestamp, level, message }) => {
      return `${timestamp} [${level.toUpperCase()}]: ${message}`
    })
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: "tunnel.log" }),
  ],
})

class PersistentTunnel {
  constructor() {
    this.tunnel = null
    this.isRunning = false
    this.reconnectAttempts = 0
    this.checkingLocalPort = false
  }

  // Verificar si el puerto local está disponible
  async isLocalPortAvailable() {
    try {
      const response = await axios.get(`http://${config.localHost}:${config.localPort}/health`, {
        timeout: 5000,
        validateStatus: () => true, // Aceptar cualquier respuesta HTTP
      })

      if (response.status !== undefined) {
        logger.info(` Puerto local ${config.localPort} está disponible (HTTP ${response.status})`)
        return true
      }
      return false
    } catch (error) {
      if (error.code === "ECONNREFUSED") {
        logger.warn(` Puerto local ${config.localPort} no está disponible (conexión rechazada)`)
      } else if (error.code === "ETIMEDOUT") {
        logger.warn(` Puerto local ${config.localPort} no responde (timeout)`)
      } else {
        logger.warn(` Error verificando puerto local: ${error.message}`)
      }
      return false
    }
  }

  // Esperar hasta que el puerto local esté disponible
  async waitForLocalPort() {
    if (this.checkingLocalPort) return
    this.checkingLocalPort = true

    logger.info(` Esperando que el puerto local ${config.localPort} esté activo...`)

    while (this.isRunning) {
      if (await this.isLocalPortAvailable()) {
        this.checkingLocalPort = false
        return true
      }

      logger.info(` Reintentando chequeo local en ${config.reconnectDelay / 1000}s...`)
      await this.sleep(config.reconnectDelay)
    }
  }

  // Crear el túnel
  async createTunnel() {
    try {
      const portAvailable = await this.isLocalPortAvailable()
      if (!portAvailable) {
        logger.warn(
          ` Puerto local ${config.localPort} aún no está listo. Entrando en modo espera...`
        )
        await this.waitForLocalPort()
      }

      const options = {
        port: config.localPort,
        local_host: config.localHost,
      }

      if (config.subdomain) {
        options.subdomain = config.subdomain
      }

      logger.info(` Creando túnel público para ${config.localHost}:${config.localPort}...`)

      this.tunnel = await localtunnel(options)
      this.reconnectAttempts = 0

      logger.info(` Túnel creado exitosamente!`)
      logger.info(` URL pública: ${this.tunnel.url}`)
      logger.info(` Mapeo: ${config.localHost}:${config.localPort} -> ${this.tunnel.url}`)

      console.log("\n" + "=".repeat(64))
      console.log(" CONFIGURACIÓN PARA ALIENTO ANDINO (FLUTTER & DX):")
      console.log("=".repeat(64))
      console.log(`URL base pública:   ${this.tunnel.url}`)
      console.log(`API Endpoint:       ${this.tunnel.url}/api`)
      console.log("\nComando Flutter listo para copiar y correr:")
      console.log(`flutter run --dart-define=API_BASE_URL=${this.tunnel.url}/api`)
      console.log("=".repeat(64) + "\n")

      this.tunnel.on("close", () => {
        logger.warn(" El túnel se cerró inesperadamente")
        this.handleTunnelClosure()
      })

      this.tunnel.on("error", (error) => {
        logger.error(` Error en el túnel: ${error.message}`)
        this.handleTunnelClosure()
      })

      return this.tunnel
    } catch (error) {
      logger.error(` Error al crear el túnel: ${error.message}`)
      await this.handleTunnelClosure()
      return null
    }
  }

  // Manejar cierre/reconexión del túnel
  async handleTunnelClosure() {
    if (!this.isRunning) return

    if (config.maxReconnectAttempts > 0 && this.reconnectAttempts >= config.maxReconnectAttempts) {
      logger.error(
        ` Límite de reintentos alcanzado (${config.maxReconnectAttempts}). Deteniendo...`
      )
      this.stop()
      return
    }

    this.reconnectAttempts++
    const delay = config.reconnectDelay * Math.min(this.reconnectAttempts, 5)
    logger.info(` Reintento de conexión ${this.reconnectAttempts} en ${delay / 1000}s...`)

    await this.sleep(delay)

    if (this.isRunning) {
      await this.createTunnel()
    }
  }

  // Verificación periódica del puerto local
  async healthCheck() {
    while (this.isRunning) {
      await this.sleep(config.healthCheckInterval)

      if (!this.isRunning) break

      const portAvailable = await this.isLocalPortAvailable()

      if (!portAvailable && this.tunnel) {
        logger.warn(
          ` Puerto local caído mientras el túnel sigue abierto. Esperando recuperación del servicio...`
        )
        await this.waitForLocalPort()

        if (this.tunnel && this.tunnel.url) {
          logger.info(` Servicio local recuperado. El túnel sigue activo en: ${this.tunnel.url}`)
        }
      }
    }
  }

  // Iniciar el servicio
  async start() {
    if (this.isRunning) {
      logger.warn(" El servicio ya está en ejecución")
      return
    }

    this.isRunning = true
    logger.info(" Iniciando servicio de túnel persistente para Aliento Andino...")

    await this.createTunnel()
    this.healthCheck()
  }

  // Detener el servicio
  async stop() {
    logger.info(" Deteniendo túnel...")
    this.isRunning = false

    if (this.tunnel) {
      this.tunnel.close()
      this.tunnel = null
    }

    logger.info(" Túnel detenido correctamente")
    process.exit(0)
  }

  sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms))
  }
}

// Manejar señales de terminación
const persistentTunnel = new PersistentTunnel()

process.on("SIGINT", async () => {
  console.log("\n Recibida señal SIGINT (Ctrl+C)")
  await persistentTunnel.stop()
})

process.on("SIGTERM", async () => {
  console.log("\n Recibida señal SIGTERM")
  await persistentTunnel.stop()
})

// Iniciar
persistentTunnel.start().catch((error) => {
  logger.error(` Error fatal: ${error.message}`)
  process.exit(1)
})
