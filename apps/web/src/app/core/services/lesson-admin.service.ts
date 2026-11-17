import { Injectable, inject, signal } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, tap, catchError, throwError } from 'rxjs';

import { environment } from '../../../environments/environment';
import { Lesson, LessonCreate, LessonUpdate, PaginatedResponse } from '../models/lesson.model';

@Injectable({ providedIn: 'root' })
export class LessonAdminService {
  private readonly http = inject(HttpClient);
  readonly apiUrl = `${environment.apiBaseUrl}/v1/lessons`;
  readonly adminUrl = `${environment.apiBaseUrl}/admin/lessons`;

  // Reactive state
  readonly lessons = signal<Lesson[]>([]);
  readonly totalLessons = signal(0);
  readonly currentLesson = signal<Lesson | null>(null);
  readonly isLoading = signal(false);
  readonly error = signal<string | null>(null);

  /**
   * Crea una nueva lección musical andina con su secuencia de notas.
   * Interceptado en /api/v1/lessons según RF-04 / SUB-05-A.
   */
  createLesson(data: LessonCreate): Observable<Lesson> {
    this.isLoading.set(true);
    this.error.set(null);
    return this.http.post<Lesson>(this.apiUrl, data).pipe(
      tap((lesson) => {
        this.lessons.update((prev) => [lesson, ...prev]);
        this.totalLessons.update((count) => count + 1);
        this.isLoading.set(false);
      }),
      catchError((err) => {
        this.isLoading.set(false);
        this.error.set(err.message || 'Error al crear lección');
        return throwError(() => err);
      }),
    );
  }

  /**
   * Actualiza una lección existente y su secuencia de notas si se proporciona.
   */
  updateLesson(id: string, data: LessonUpdate): Observable<Lesson> {
    this.isLoading.set(true);
    this.error.set(null);
    return this.http.put<Lesson>(`${this.apiUrl}/${id}`, data).pipe(
      tap((updated) => {
        this.lessons.update((prev) => prev.map((l) => (l.id === id ? { ...l, ...updated } : l)));
        if (this.currentLesson()?.id === id) {
          this.currentLesson.set(updated);
        }
        this.isLoading.set(false);
      }),
      catchError((err) => {
        this.isLoading.set(false);
        this.error.set(err.message || 'Error al actualizar lección');
        return throwError(() => err);
      }),
    );
  }

  /**
   * Obtiene el detalle de una lección por ID con sus notas.
   */
  getLesson(id: string): Observable<Lesson> {
    this.isLoading.set(true);
    return this.http.get<Lesson>(`${this.apiUrl}/${id}`).pipe(
      tap((lesson) => {
        this.currentLesson.set(lesson);
        this.isLoading.set(false);
      }),
      catchError((err) => {
        this.isLoading.set(false);
        return throwError(() => err);
      }),
    );
  }

  /**
   * Carga lecciones paginadas con filtros de instrumento y dificultad.
   */
  loadLessons(params?: {
    page?: number;
    limit?: number;
    instrument?: string;
    difficulty?: string;
    search?: string;
  }): Observable<PaginatedResponse<Lesson>> {
    this.isLoading.set(true);
    let httpParams = new HttpParams();
    if (params?.page) httpParams = httpParams.set('page', params.page.toString());
    if (params?.limit) httpParams = httpParams.set('limit', params.limit.toString());
    if (params?.instrument) httpParams = httpParams.set('instrument', params.instrument);
    if (params?.difficulty) httpParams = httpParams.set('difficulty', params.difficulty);
    if (params?.search) httpParams = httpParams.set('search', params.search);

    return this.http.get<PaginatedResponse<Lesson>>(this.adminUrl, { params: httpParams }).pipe(
      tap((res) => {
        this.lessons.set(res.items);
        this.totalLessons.set(res.total);
        this.isLoading.set(false);
      }),
      catchError((err) => {
        this.isLoading.set(false);
        return throwError(() => err);
      }),
    );
  }

  /**
   * Elimina una lección (soft delete).
   */
  deleteLesson(id: string): Observable<{ message: string }> {
    return this.http.delete<{ message: string }>(`${this.adminUrl}/${id}`).pipe(
      tap(() => {
        this.lessons.update((prev) => prev.filter((l) => l.id !== id));
        this.totalLessons.update((count) => Math.max(0, count - 1));
      }),
    );
  }
}
