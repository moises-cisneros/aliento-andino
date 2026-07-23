/// Modelos del módulo de administración de usuarios.

export interface AdminUser {
  id: string;
  email: string;
  username: string;
  full_name: string;
  avatar_url: string | null;
  is_active: boolean;
  is_admin: boolean;
  is_banned: boolean;
  ban_reason: string | null;
  xp_level: number;
  followers_count: number;
  posts_count: number;
  created_at: string;
}

export interface AdminUserPaginatedResponse {
  items: AdminUser[];
  total: number;
  page: number;
  pages: number;
}
