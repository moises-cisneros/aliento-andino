import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';

export interface FunnelData {
  registered: number;
  practiced: number;
  premium: number;
  practiced_pct: number;
  premium_pct: number;
  premium_of_practiced_pct: number;
}

export interface RetentionData {
  total_users: number;
  active_7d: number;
  active_30d: number;
  active_7d_pct: number;
  active_30d_pct: number;
  active_premium: number;
  expired_premium: number;
}

export interface DataPoint {
  name: string;
  value: number;
}

export interface LessonPerformance {
  title: string;
  attempts: number;
  avg_score: number;
}

export interface AiUsageBucket {
  calls: number;
  input_tokens: number;
  output_tokens: number;
  total_tokens: number;
  cost_usd: number;
}

export interface AiUsage {
  model: string;
  total_feedback_calls: number;
  feedback_calls_30d: number;
  est_cost_per_call_usd: number;
  est_total_cost_usd: number;
  est_cost_30d_usd: number;
  assumptions: {
    avg_input_tokens: number;
    avg_output_tokens: number;
    price_input_per_1m_usd: number;
    price_output_per_1m_usd: number;
  };
  has_real: boolean;
  real: {
    total: AiUsageBucket;
    last30: AiUsageBucket;
    by_kind: Record<string, AiUsageBucket>;
  };
  price_input_per_1m_usd: number;
  price_output_per_1m_usd: number;
  note: string;
}

@Injectable({ providedIn: 'root' })
export class BusinessAnalyticsService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiBaseUrl}/admin/analytics`;

  getFunnel(): Observable<FunnelData> {
    return this.http.get<FunnelData>(`${this.url}/funnel`);
  }

  getRetention(): Observable<RetentionData> {
    return this.http.get<RetentionData>(`${this.url}/retention`);
  }

  getPremiumOverTime(days = 90): Observable<DataPoint[]> {
    return this.http.get<DataPoint[]>(`${this.url}/premium-over-time`, {
      params: new HttpParams().set('days', days),
    });
  }

  getLessonPerformance(limit = 10): Observable<LessonPerformance[]> {
    return this.http.get<LessonPerformance[]>(`${this.url}/lesson-performance`, {
      params: new HttpParams().set('limit', limit),
    });
  }

  getAiUsage(): Observable<AiUsage> {
    return this.http.get<AiUsage>(`${this.url}/ai-usage`);
  }

  getAiUsageOverTime(days = 30): Observable<DataPoint[]> {
    return this.http.get<DataPoint[]>(`${this.url}/ai-usage-over-time`, {
      params: new HttpParams().set('days', days),
    });
  }
}
