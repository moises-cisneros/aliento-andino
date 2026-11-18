declare global {
  interface Window {
    __env?: {
      apiBaseUrl?: string;
    };
  }
}

// Configuración del entorno de desarrollo
export const environment = {
  production: false,
  apiBaseUrl:
    (typeof window !== 'undefined' && window.__env?.apiBaseUrl) || 'http://localhost:8050/api',
};
