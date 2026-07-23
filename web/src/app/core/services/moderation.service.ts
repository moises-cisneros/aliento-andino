import { Injectable, inject, signal } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, tap } from 'rxjs';

import { environment } from '../../../environments/environment';
import {
  Report, SocialStats, BannedUser, PaginatedResponse,
} from '../models/social.model';

@Injectable({ providedIn: 'root' })
export class ModerationService {
  private readonly adminUrl = `${environment.apiBaseUrl}/admin`;
  private readonly http = inject(HttpClient);

  // Estado reactivo
  readonly reports = signal<Report[]>([]);
  readonly totalReports = signal(0);
  readonly socialStats = signal<SocialStats | null>(null);
  readonly isLoading = signal(false);

  loadReports(params?: {
    page?: number;
    limit?: number;
    status?: string;
    reason?: string;
  }): Observable<PaginatedResponse<Report>> {
    this.isLoading.set(true);
    let httpParams = new HttpParams();
    if (params?.page) httpParams = httpParams.set('page', params.page);
    if (params?.limit) httpParams = httpParams.set('limit', params.limit);
    if (params?.status) httpParams = httpParams.set('status', params.status);
    if (params?.reason) httpParams = httpParams.set('reason', params.reason);

    return this.http
      .get<PaginatedResponse<Report>>(`${this.adminUrl}/reports`, { params: httpParams })
      .pipe(
        tap((res) => {
          this.reports.set(res.items);
          this.totalReports.set(res.total);
          this.isLoading.set(false);
        }),
      );
  }

  updateReportStatus(reportId: string, status: string): Observable<Report> {
    return this.http.put<Report>(`${this.adminUrl}/reports/${reportId}`, { status });
  }

  deletePost(postId: string): Observable<{ message: string }> {
    return this.http.delete<{ message: string }>(`${this.adminUrl}/posts/${postId}`);
  }

  deleteComment(commentId: string): Observable<{ message: string }> {
    return this.http.delete<{ message: string }>(`${this.adminUrl}/comments/${commentId}`);
  }

  banUser(userId: string, reason: string): Observable<{ message: string }> {
    return this.http.post<{ message: string }>(`${this.adminUrl}/users/${userId}/ban`, { reason });
  }

  unbanUser(userId: string): Observable<{ message: string }> {
    return this.http.post<{ message: string }>(`${this.adminUrl}/users/${userId}/unban`, {});
  }

  loadSocialStats(): Observable<SocialStats> {
    return this.http
      .get<SocialStats>(`${this.adminUrl}/social/stats`)
      .pipe(tap((s) => this.socialStats.set(s)));
  }

  searchBannedUsers(params?: {
    page?: number;
    limit?: number;
  }): Observable<PaginatedResponse<BannedUser>> {
    const httpParams = new HttpParams().set('q', '').set('page', params?.page ?? 1).set('limit', params?.limit ?? 50);
    // Usado indirectamente: la búsqueda de usuarios baneados se filtra client-side
    return this.http.get<PaginatedResponse<BannedUser>>(
      `${environment.apiBaseUrl}/users/search`,
      { params: httpParams },
    );
  }
}
