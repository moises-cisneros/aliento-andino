/// Modelos del módulo social para administración.

export interface UserSummary {
  id: string;
  username: string;
  full_name: string;
  avatar_url: string | null;
  posts_count?: number;
}

export interface PostResponse {
  id: string;
  user: UserSummary;
  content: string;
  post_type: string;
  media_url: string | null;
  likes_count: number;
  comments_count: number;
  is_active: boolean;
  is_reported: boolean;
  created_at: string;
  updated_at: string | null;
}

export interface CommentResponse {
  id: string;
  post_id: string;
  user: UserSummary;
  content: string;
  created_at: string;
}

export interface Report {
  id: string;
  reporter: UserSummary;
  post_id: string | null;
  comment_id: string | null;
  reported_user_id: string | null;
  reason: string;
  description: string | null;
  status: 'pending' | 'reviewed' | 'resolved' | 'dismissed';
  reviewed_by: string | null;
  reviewed_at: string | null;
  created_at: string;
  // Contenido reportado (campos planos del backend)
  post_content: string | null;
  comment_content: string | null;
  reported_username: string | null;
}

export interface SocialStats {
  total_posts: number;
  total_comments: number;
  total_likes: number;
  total_reports_pending: number;
  total_users_banned: number;
  most_active_users: UserSummary[];
}

export interface BannedUser {
  id: string;
  username: string;
  full_name: string;
  email: string;
  is_banned: boolean;
  ban_reason: string | null;
  created_at: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  pages: number;
}
