export interface AdminSubscription {
  id: string;
  email: string;
  username: string;
  full_name: string | null;
  subscription_status: string; // "free" | "premium"
  subscription_plan: string | null; // "monthly" | "annual" | "trial"
  plan_label: string | null;
  subscription_started_at: string | null;
  subscription_expires_at: string | null;
  subscription_trial_used: boolean;
  is_premium: boolean;
  days_until_expiry: number | null;
}

export interface AdminSubscriptionPaginatedResponse {
  items: AdminSubscription[];
  total: number;
  page: number;
  pages: number;
}

export interface SubscriptionSummary {
  total_users: number;
  premium_active: number;
  free: number;
  monthly: number;
  annual: number;
  trial: number;
  trials_used: number;
  estimated_mrr_usd: number;
  estimated_arr_usd: number;
  simulated: boolean;
}
