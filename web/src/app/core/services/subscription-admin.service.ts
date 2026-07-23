import { Injectable, inject, signal } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, tap } from 'rxjs';

import { environment } from '../../../environments/environment';
import {
  AdminSubscription,
  AdminSubscriptionPaginatedResponse,
  SubscriptionSummary,
} from '../models/subscription.model';

@Injectable({ providedIn: 'root' })
export class SubscriptionAdminService {
  private readonly adminUrl = `${environment.apiBaseUrl}/admin/subscriptions`;
  private readonly http = inject(HttpClient);

  // Estado reactivo
  readonly subscriptions = signal<AdminSubscription[]>([]);
  readonly total = signal(0);
  readonly totalPages = signal(0);
  readonly isLoading = signal(false);
  readonly summary = signal<SubscriptionSummary | null>(null);

  loadSubscriptions(params?: {
    page?: number;
    limit?: number;
    search?: string;
    status?: string;
    plan?: string;
  }): Observable<AdminSubscriptionPaginatedResponse> {
    this.isLoading.set(true);
    let httpParams = new HttpParams();
    if (params?.page) httpParams = httpParams.set('page', params.page);
    if (params?.limit) httpParams = httpParams.set('limit', params.limit);
    if (params?.search) httpParams = httpParams.set('search', params.search);
    if (params?.status) httpParams = httpParams.set('status', params.status);
    if (params?.plan) httpParams = httpParams.set('plan', params.plan);

    return this.http
      .get<AdminSubscriptionPaginatedResponse>(this.adminUrl, { params: httpParams })
      .pipe(
        tap((res) => {
          this.subscriptions.set(res.items);
          this.total.set(res.total);
          this.totalPages.set(res.pages);
          this.isLoading.set(false);
        }),
      );
  }

  loadSummary(): Observable<SubscriptionSummary> {
    return this.http
      .get<SubscriptionSummary>(`${this.adminUrl}/summary`)
      .pipe(tap((s) => this.summary.set(s)));
  }

  grant(userId: string, plan: string): Observable<unknown> {
    return this.http.post(`${this.adminUrl}/${userId}/grant`, { plan });
  }

  cancel(userId: string): Observable<unknown> {
    return this.http.post(`${this.adminUrl}/${userId}/cancel`, {});
  }
}
