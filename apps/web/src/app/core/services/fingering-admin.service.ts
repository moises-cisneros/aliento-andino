import { Injectable, inject, signal } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, tap, catchError, throwError } from 'rxjs';

import { environment } from '../../../environments/environment';
import { Fingering, FingeringCreate } from '../models/fingering.model';

@Injectable({ providedIn: 'root' })
export class FingeringAdminService {
  private readonly http = inject(HttpClient);
  readonly apiUrl = `${environment.apiBaseUrl}/v1/fingerings`;

  // Reactive state
  readonly fingerings = signal<Fingering[]>([]);
  readonly isLoading = signal(false);
  readonly error = signal<string | null>(null);

  /**
   * Obtiene la lista de digitaciones del catálogo, opcionalmente filtrada por instrumento.
   */
  getFingerings(instrument?: string): Observable<Fingering[]> {
    this.isLoading.set(true);
    this.error.set(null);

    let params = new HttpParams();
    if (instrument && instrument !== 'all') {
      params = params.set('instrument', instrument);
    }

    return this.http.get<Fingering[]>(this.apiUrl, { params }).pipe(
      tap((data) => {
        this.fingerings.set(data);
        this.isLoading.set(false);
      }),
      catchError((err) => {
        this.isLoading.set(false);
        this.error.set(err.message || 'Error al cargar digitaciones');
        return throwError(() => err);
      }),
    );
  }

  /**
   * Registra una nueva digitación en el catálogo oficial.
   * Si ya existe una digitación principal para esa nota e instrumento,
   * el backend retornará HTTP 409 Conflict.
   */
  createFingering(data: FingeringCreate): Observable<Fingering> {
    this.isLoading.set(true);
    this.error.set(null);

    return this.http.post<Fingering>(this.apiUrl, data).pipe(
      tap((created) => {
        this.fingerings.update((prev) => [created, ...prev]);
        this.isLoading.set(false);
      }),
      catchError((err) => {
        this.isLoading.set(false);
        this.error.set(err.error?.detail || err.message || 'Error al guardar digitación');
        return throwError(() => err);
      }),
    );
  }

  /**
   * Elimina una digitación por su ID.
   */
  deleteFingering(id: string): Observable<void> {
    this.isLoading.set(true);
    this.error.set(null);

    return this.http.delete<void>(`${this.apiUrl}/${id}`).pipe(
      tap(() => {
        this.fingerings.update((prev) => prev.filter((f) => f.id !== id));
        this.isLoading.set(false);
      }),
      catchError((err) => {
        this.isLoading.set(false);
        this.error.set(err.error?.detail || err.message || 'Error al eliminar digitación');
        return throwError(() => err);
      }),
    );
  }
}
