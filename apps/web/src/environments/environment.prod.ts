declare global {
  interface Window {
    __env?: {
      apiBaseUrl?: string;
    };
  }
}

// Configuración del entorno de producción
export const environment = {
  production: true,
  apiBaseUrl: (typeof window !== 'undefined' && window.__env?.apiBaseUrl) || '/api',
};
