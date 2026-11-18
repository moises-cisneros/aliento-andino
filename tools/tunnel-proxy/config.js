require("dotenv").config()

module.exports = {
  // Puerto local a reenviar (backend de Aliento Andino por defecto en 8050)
  localPort: parseInt(process.env.LOCAL_PORT || "8050", 10),

  // Dominio personalizado opcional (ej: aliento-andino-dev)
  subdomain: process.env.SUBDOMAIN || null,

  // Configuración de reconexión
  reconnectDelay: parseInt(process.env.RECONNECT_DELAY || "5000", 10), // 5 segundos
  maxReconnectAttempts: parseInt(process.env.MAX_RECONNECT_ATTEMPTS || "0", 10), // 0 = infinito

  // Verificación de puerto local
  healthCheckInterval: parseInt(process.env.HEALTH_CHECK_INTERVAL || "30000", 10), // 30 segundos
  localHost: process.env.LOCAL_HOST || "localhost",

  // Logging
  logLevel: process.env.LOG_LEVEL || "info",
}
