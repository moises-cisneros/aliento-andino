/// Modelos del módulo de rankings para administración.

export interface RankingEntry {
  rank: number;
  user_id: string;
  username: string;
  full_name: string;
  avatar_url: string | null;
  total_xp: number;
  weekly_xp: number;
  level: number;
  total_lessons_completed: number;
}

export interface StreakRankingEntry {
  rank: number;
  user_id: string;
  username: string;
  full_name: string;
  avatar_url: string | null;
  current_streak: number;
  longest_streak: number;
}

export interface LeaderboardResponse {
  leaderboard: RankingEntry[];
  total_participants: number;
  my_rank: number;
  my_total_xp: number;
  my_level: number;
}

export interface WeeklyLeaderboardResponse {
  leaderboard: RankingEntry[];
  total_participants: number;
  week_start: string;
  week_end: string;
  days_remaining: number;
  my_rank: number;
  my_weekly_xp: number;
}

export interface StreakLeaderboardResponse {
  leaderboard: StreakRankingEntry[];
  total_participants: number;
  my_rank: number;
  my_current_streak: number;
}

export interface Achievement {
  id: string;
  code: string;
  name: string;
  description: string;
  icon: string;
  category: string;
  rarity: string;
  xp_reward: number;
  requirement_type: string;
  requirement_value: number;
  is_active: boolean;
  created_at: string;
}

export interface AchievementCreate {
  code: string;
  name: string;
  description: string;
  icon?: string;
  category: string;
  rarity?: string;
  xp_reward?: number;
  requirement_type: string;
  requirement_value: number;
}

export interface AchievementUpdate {
  name?: string;
  description?: string;
  icon?: string;
  category?: string;
  rarity?: string;
  xp_reward?: number;
  requirement_type?: string;
  requirement_value?: number;
  is_active?: boolean;
}

export interface RankingStats {
  total_users_with_xp: number;
  total_xp_awarded: number;
  total_achievements_unlocked: number;
  average_level: number;
  max_level: number;
  top_user: {
    user_id: string;
    username: string;
    total_xp: number;
    level: number;
  } | null;
}
