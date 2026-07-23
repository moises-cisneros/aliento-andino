import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface DataPoint {
  name: string;
  value: number;
}

export interface MultiSeries {
  name: string;
  series: DataPoint[];
}

export interface OverviewData {
  total_users: number;
  active_users: number;
  banned_users: number;
  total_lessons: number;
  total_sessions: number;
  total_posts: number;
  total_comments: number;
  total_likes: number;
  pending_reports: number;
}

export interface SocialOverTime {
  posts: DataPoint[];
  comments: DataPoint[];
  likes: DataPoint[];
}

@Injectable({ providedIn: 'root' })
export class AnalyticsService {
  private http = inject(HttpClient);
  private url = `${environment.apiBaseUrl}/admin/analytics`;

  getOverview(): Observable<OverviewData> {
    return this.http.get<OverviewData>(`${this.url}/overview`);
  }

  getUsersOverTime(days = 30): Observable<DataPoint[]> {
    return this.http.get<DataPoint[]>(`${this.url}/users-over-time`, { params: { days } });
  }

  getPracticeOverTime(days = 30): Observable<DataPoint[]> {
    return this.http.get<DataPoint[]>(`${this.url}/practice-over-time`, { params: { days } });
  }

  getSocialOverTime(days = 30): Observable<SocialOverTime> {
    return this.http.get<SocialOverTime>(`${this.url}/social-over-time`, { params: { days } });
  }

  getLessonsByCategory(): Observable<DataPoint[]> {
    return this.http.get<DataPoint[]>(`${this.url}/lessons-by-category`);
  }

  getLessonsByDifficulty(): Observable<DataPoint[]> {
    return this.http.get<DataPoint[]>(`${this.url}/lessons-by-difficulty`);
  }

  getReportsByStatus(): Observable<DataPoint[]> {
    return this.http.get<DataPoint[]>(`${this.url}/reports-by-status`);
  }

  getReportsOverTime(days = 30): Observable<DataPoint[]> {
    return this.http.get<DataPoint[]>(`${this.url}/reports-over-time`, { params: { days } });
  }

  getTopLessons(limit = 10): Observable<DataPoint[]> {
    return this.http.get<DataPoint[]>(`${this.url}/top-lessons`, { params: { limit } });
  }
}
