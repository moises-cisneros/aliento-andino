import { Injectable, inject, signal } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';

import { environment } from '../../../environments/environment';

/**
 * Descarga CSVs del admin. Los endpoints requieren auth (el interceptor agrega
 * el token), por eso no se puede usar un <a href> plano: se baja como blob y se
 * dispara la descarga con un anchor temporal.
 */
@Injectable({ providedIn: 'root' })
export class CsvExportService {
  private readonly base = `${environment.apiBaseUrl}/admin/export`;
  private readonly http = inject(HttpClient);

  /** Endpoint que se está descargando (para deshabilitar el botón). */
  readonly downloading = signal<string | null>(null);

  exportUsers(filters: { search?: string; is_banned?: boolean; is_admin?: boolean } = {}): void {
    let params = new HttpParams();
    if (filters.search) params = params.set('search', filters.search);
    if (filters.is_banned !== undefined) params = params.set('is_banned', filters.is_banned);
    if (filters.is_admin !== undefined) params = params.set('is_admin', filters.is_admin);
    this.download('users.csv', 'usuarios.csv', params);
  }

  exportSubscriptions(filters: { status?: string; plan?: string; search?: string } = {}): void {
    let params = new HttpParams();
    if (filters.status) params = params.set('status', filters.status);
    if (filters.plan) params = params.set('plan', filters.plan);
    if (filters.search) params = params.set('search', filters.search);
    this.download('subscriptions.csv', 'suscripciones.csv', params);
  }

  exportLessonPerformance(): void {
    this.download('lesson-performance.csv', 'rendimiento-lecciones.csv', new HttpParams());
  }

  private download(endpoint: string, filename: string, params: HttpParams): void {
    this.downloading.set(endpoint);
    this.http
      .get(`${this.base}/${endpoint}`, { params, responseType: 'blob' })
      .subscribe({
        next: (blob) => {
          const url = URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url;
          a.download = filename;
          a.click();
          URL.revokeObjectURL(url);
          this.downloading.set(null);
        },
        error: () => this.downloading.set(null),
      });
  }
}
