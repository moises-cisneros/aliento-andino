import { Injectable, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap } from 'rxjs';

import { environment } from '../../../environments/environment';
import {
  Achievement,
  AchievementCreate,
  AchievementUpdate,
  LeaderboardResponse,
  WeeklyLeaderboardResponse,
  StreakLeaderboardResponse,
  RankingStats,
} from '../models/ranking.model';

@Injectable({ providedIn: 'root' })
export class RankingService {
  private readonly apiUrl = `${environment.apiBaseUrl}/rankings`;
  private readonly adminUrl = `${environment.apiBaseUrl}/admin`;
  private readonly http = inject(HttpClient);

  // Estado reactivo
  readonly globalLeaderboard = signal<LeaderboardResponse | null>(null);
  readonly weeklyLeaderboard = signal<WeeklyLeaderboardResponse | null>(null);
  readonly streakLeaderboard = signal<StreakLeaderboardResponse | null>(null);
  readonly achievements = signal<Achievement[]>([]);
  readonly rankingStats = signal<RankingStats | null>(null);
  readonly isLoading = signal(false);

  // ── Leaderboards (público) ──

  loadGlobalLeaderboard(limit = 50): Observable<LeaderboardResponse> {
    this.isLoading.set(true);
    return this.http
      .get<LeaderboardResponse>(`${this.apiUrl}/global`, { params: { limit } })
      .pipe(
        tap((res) => {
          this.globalLeaderboard.set(res);
          this.isLoading.set(false);
        }),
      );
  }

  loadWeeklyLeaderboard(limit = 50): Observable<WeeklyLeaderboardResponse> {
    this.isLoading.set(true);
    return this.http
      .get<WeeklyLeaderboardResponse>(`${this.apiUrl}/weekly`, { params: { limit } })
      .pipe(
        tap((res) => {
          this.weeklyLeaderboard.set(res);
          this.isLoading.set(false);
        }),
      );
  }

  loadStreakLeaderboard(limit = 50): Observable<StreakLeaderboardResponse> {
    this.isLoading.set(true);
    return this.http
      .get<StreakLeaderboardResponse>(`${this.apiUrl}/streaks`, { params: { limit } })
      .pipe(
        tap((res) => {
          this.streakLeaderboard.set(res);
          this.isLoading.set(false);
        }),
      );
  }

  // ── Admin: Achievements CRUD ──

  loadAchievements(): Observable<Achievement[]> {
    return this.http
      .get<Achievement[]>(`${this.adminUrl}/achievements`)
      .pipe(tap((res) => this.achievements.set(res)));
  }

  createAchievement(data: AchievementCreate): Observable<Achievement> {
    return this.http.post<Achievement>(`${this.adminUrl}/achievements`, data);
  }

  updateAchievement(id: string, data: AchievementUpdate): Observable<Achievement> {
    return this.http.put<Achievement>(`${this.adminUrl}/achievements/${id}`, data);
  }

  deleteAchievement(id: string): Observable<{ message: string }> {
    return this.http.delete<{ message: string }>(`${this.adminUrl}/achievements/${id}`);
  }

  // ── Admin: Stats ──

  loadRankingStats(): Observable<RankingStats> {
    return this.http
      .get<RankingStats>(`${this.adminUrl}/rankings/stats`)
      .pipe(tap((s) => this.rankingStats.set(s)));
  }
}
