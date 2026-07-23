import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';

export interface AuditLogEntry {
  id: string;
  admin_id: string | null;
  admin_email: string | null;
  action: string;
  target_type: string | null;
  target_id: string | null;
  detail: Record<string, unknown> | null;
  created_at: string | null;
}

export interface AuditLogPage {
  items: AuditLogEntry[];
  total: number;
  page: number;
  pages: number;
}

export interface AuditFilters {
  page?: number;
  limit?: number;
  action?: string;
  target_type?: string;
}

@Injectable({ providedIn: 'root' })
export class AuditAdminService {
  private readonly url = `${environment.apiBaseUrl}/admin/audit`;
  private readonly http = inject(HttpClient);

  list(filters: AuditFilters = {}): Observable<AuditLogPage> {
    let params = new HttpParams();
    if (filters.page) params = params.set('page', filters.page);
    if (filters.limit) params = params.set('limit', filters.limit);
    if (filters.action) params = params.set('action', filters.action);
    if (filters.target_type) params = params.set('target_type', filters.target_type);
    return this.http.get<AuditLogPage>(this.url, { params });
  }
}
