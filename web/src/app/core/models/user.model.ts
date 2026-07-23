/// Interfaz del usuario devuelta por el backend.
export interface User {
  id: string;
  email: string;
  username: string;
  full_name: string;
  avatar_url: string | null;
  bio: string | null;
  is_active: boolean;
  is_admin: boolean;
  is_verified: boolean;
  auth_provider: string;
  created_at: string;
  updated_at: string | null;
}

/// Respuesta del endpoint de login/register.
export interface AuthResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  user: User;
}

/// Respuesta del endpoint de refresh (con rotación de tokens).
export interface RefreshResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
}

/// Respuesta genérica con mensaje.
export interface MessageResponse {
  message: string;
}
