import { Injectable, inject, signal } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, tap } from 'rxjs';

import { environment } from '../../../environments/environment';
import { AdminUser, AdminUserPaginatedResponse } from '../models/admin-user.model';

@Injectable({ providedIn: 'root' })
export class UserAdminService {
  private readonly adminUrl = `${environment.apiBaseUrl}/admin`;
  private readonly http = inject(HttpClient);

  // Estado reactivo
  readonly users = signal<AdminUser[]>([]);
  readonly totalUsers = signal(0);
  readonly totalPages = signal(0);
  readonly isLoading = signal(false);

  loadUsers(params?: {
    page?: number;
    limit?: number;
    search?: string;
    is_banned?: boolean;
    is_admin?: boolean;
  }): Observable<AdminUserPaginatedResponse> {
    this.isLoading.set(true);
    let httpParams = new HttpParams();
    if (params?.page) httpParams = httpParams.set('page', params.page);
    if (params?.limit) httpParams = httpParams.set('limit', params.limit);
    if (params?.search) httpParams = httpParams.set('search', params.search);
    if (params?.is_banned !== undefined) httpParams = httpParams.set('is_banned', params.is_banned);
    if (params?.is_admin !== undefined) httpParams = httpParams.set('is_admin', params.is_admin);

    return this.http
      .get<AdminUserPaginatedResponse>(`${this.adminUrl}/users`, { params: httpParams })
      .pipe(
        tap((res) => {
          this.users.set(res.items);
          this.totalUsers.set(res.total);
          this.totalPages.set(res.pages);
          this.isLoading.set(false);
        }),
      );
  }

  banUser(userId: string, reason: string): Observable<{ message: string }> {
    return this.http.post<{ message: string }>(`${this.adminUrl}/users/${userId}/ban`, { reason });
  }

  unbanUser(userId: string): Observable<{ message: string }> {
    return this.http.post<{ message: string }>(`${this.adminUrl}/users/${userId}/unban`, {});
  }

  setAdmin(userId: string, isAdmin: boolean): Observable<{ id: string; is_admin: boolean }> {
    return this.http.post<{ id: string; is_admin: boolean }>(
      `${this.adminUrl}/users/${userId}/set-admin`,
      { is_admin: isAdmin },
    );
  }

  resetPassword(userId: string): Observable<{ message: string }> {
    return this.http.post<{ message: string }>(
      `${this.adminUrl}/users/${userId}/reset-password`,
      {},
    );
  }

  getUserDetail(userId: string): Observable<AdminUserDetail> {
    return this.http.get<AdminUserDetail>(`${this.adminUrl}/users/${userId}`);
  }
}

export interface AdminUserDetail extends AdminUser {
  auth_provider: string;
  subscription_status: string;
  subscription_plan: string | null;
  is_premium: boolean;
  practice: {
    sessions: number;
    avg_score: number | null;
    distinct_lessons: number;
    last_active: string | null;
  };
}
